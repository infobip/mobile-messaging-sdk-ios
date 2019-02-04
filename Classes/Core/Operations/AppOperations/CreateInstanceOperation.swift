//
//  CreateInstanceOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 12/11/2018.
//

import Foundation

class CreateInstanceOperation : Operation {
	let mmContext: MobileMessaging
	let currentInstallation: Installation
	let dirtyInstallation: Installation
	let finishBlock: ((FetchInstanceDataResult) -> Void)?
	var result: FetchInstanceDataResult = FetchInstanceDataResult.Cancel
	let requireResponse: Bool
	var body: [String: Any]

	init?(currentInstallation: Installation, dirtyInstallation: Installation, mmContext: MobileMessaging, requireResponse: Bool, finishBlock: ((FetchInstanceDataResult) -> Void)?) {
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = requireResponse
		self.currentInstallation = currentInstallation
		self.dirtyInstallation = dirtyInstallation

		if let _ = dirtyInstallation.pushServiceToken {
			self.body = InstallationDataMapper.requestPayload(currentInstallation: self.currentInstallation, dirtyInstallation: dirtyInstallation, internalData: mmContext.internalData())
			if self.body.isEmpty {
				MMLogWarn("[CreateInstanceOperation] There is no data to send. Aborting...")
				return nil
			}
		} else {
			MMLogWarn("[CreateInstanceOperation] There is no device token. Aborting...")
			return nil
		}
	}

	override func execute() {
		guard !isCancelled else {
			MMLogDebug("[CreateInstanceOperation] cancelled...")
			finish()
			return
		}
		MMLogDebug("[CreateInstanceOperation] started...")
		sendServerRequestIfNeeded()
	}

	private func sendServerRequestIfNeeded() {
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogWarn("[CreateInstanceOperation] Registration is not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.InvalidRegistration))
			return
		}
		body["notificationsEnabled"] = true // this is a workaround because registration may happen before user granted any permissions, so that they may be undefined. Forcing true.
		mmContext.remoteApiProvider.postInstance(applicationCode: mmContext.applicationCode, body: body) { (result) in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: FetchInstanceDataResult) {
		self.result = result
		guard !isCancelled else {
			MMLogDebug("[CreateInstanceOperation] cancelled.")
			return
		}
		switch result {
		case .Success(let response):
			if response.pushRegistrationId != currentInstallation.pushRegistrationId {
				// this is to force system data sync for the new registration
				let id = mmContext.internalData()
				id.systemDataHash = 0
				id.archiveCurrent()
			}

			response.archiveAll()

			UserEventsManager.postInstallationSyncedEvent(currentInstallation)
			if mmContext.keychain.pushRegId == nil {
				mmContext.keychain.pushRegId = response.pushRegistrationId
			}
			MMLogDebug("[CreateInstanceOperation] successfully created registration \(String(describing: response.pushRegistrationId))")
		case .Failure(let error):
			MMLogError("[CreateInstanceOperation] sync request failed with error: \(error.orNil)")
		case .Cancel:
			MMLogWarn("[CreateInstanceOperation] sync request cancelled.")
		}
	}

	override func finished(_ errors: [NSError]) {
		MMLogDebug("[CreateInstanceOperation] finished with errors: \(errors)")
		finishBlock?(self.result)
	}
}
