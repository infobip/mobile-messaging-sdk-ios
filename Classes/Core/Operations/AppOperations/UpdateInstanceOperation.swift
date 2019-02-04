//
//  SaveIntanceOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 09/11/2018.
//

import Foundation

class UpdateInstanceOperation : Operation {
	let mmContext: MobileMessaging
	let currentInstallation: Installation
	let body: RequestBody
	let finishBlock: ((UpdateInstanceDataResult) -> Void)?
	var result: UpdateInstanceDataResult = UpdateInstanceDataResult.Cancel
	let requireResponse: Bool
	let registrationPushRegIdToUpdate: String
	let authPushRegistrationId: String
	let dirtyInstallation: Installation

	init?(currentInstallation: Installation, dirtyInstallation: Installation?, registrationPushRegIdToUpdate: String?, mmContext: MobileMessaging, requireResponse: Bool, finishBlock: ((UpdateInstanceDataResult) -> Void)?) {
		self.currentInstallation = currentInstallation
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = requireResponse

		if let dirtyInstallation = dirtyInstallation {
			self.dirtyInstallation = dirtyInstallation
			self.body = InstallationDataMapper.requestPayload(currentInstallation: currentInstallation, dirtyInstallation: dirtyInstallation, internalData: mmContext.internalData())
			if self.body.isEmpty {
				MMLogWarn("[UpdateInstanceOperation] There is no data to send. Aborting...")
				return nil
			}
		} else {
			MMLogDebug("[UpdateInstanceOperation] There are no attributes to sync save. Aborting...")
			return nil
		}

		if let registrationPushRegIdToUpdate = registrationPushRegIdToUpdate {
			self.registrationPushRegIdToUpdate = registrationPushRegIdToUpdate
		} else {
			MMLogWarn("[UpdateInstanceOperation] There is no reference registration. Aborting...")
			return nil
		}

		if let authPushRegistrationId = currentInstallation.pushRegistrationId  {
			self.authPushRegistrationId = authPushRegistrationId
		} else {
			MMLogWarn("[UpdateInstanceOperation] There is no authentication registration. Aborting...")
			return nil
		}
	}

	override func execute() {
		guard !isCancelled else {
			MMLogDebug("[UpdateInstanceOperation] cancelled...")
			finish()
			return
		}
		MMLogDebug("[UpdateInstanceOperation] started...")
		sendServerRequestIfNeeded()
	}

	private func sendServerRequestIfNeeded() {
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogWarn("[UpdateInstanceOperation] Registration is not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.InvalidRegistration))
			return
		}
		
		mmContext.remoteApiProvider.patchInstance(applicationCode: mmContext.applicationCode, authPushRegistrationId: authPushRegistrationId, refPushRegistrationId: registrationPushRegIdToUpdate, body: body) { (result) in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: UpdateInstanceDataResult) {
		self.result = result
		guard authPushRegistrationId == registrationPushRegIdToUpdate else {
			MMLogDebug("[UpdateInstanceOperation] updated other installation, no need to persist data. Finishing.")
			return
		}
		guard !isCancelled else {
			MMLogDebug("[UpdateInstanceOperation] cancelled.")
			return
		}
		switch result {
		case .Success:

			let id = mmContext.internalData()
			id.systemDataHash = Int64(MobileMessaging.userAgent.systemData.hashValue)
			id.archiveCurrent()

			dirtyInstallation.archiveCurrent()

			UserEventsManager.postInstallationSyncedEvent(mmContext.currentInstallation())
			MMLogDebug("[UpdateInstanceOperation] successfully synced")
		case .Failure(let error):
			MMLogError("[UpdateInstanceOperation] sync request failed with error: \(error.orNil)")
		case .Cancel:
			MMLogWarn("[UpdateInstanceOperation] sync request cancelled.")
		}
	}

	override func finished(_ errors: [NSError]) {
		MMLogDebug("[UpdateInstanceOperation] finished with errors: \(errors)")
		finishBlock?(self.result)
	}
}
