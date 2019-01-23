//
//  CreateInstanceOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 12/11/2018.
//

import Foundation

class CreateInstanceOperation : Operation {
	let mmContext: MobileMessaging
	let installation: InstallationDataService
	var attributesSet: AttributesSet
	let finishBlock: ((FetchInstanceDataResult) -> Void)?
	var result: FetchInstanceDataResult = FetchInstanceDataResult.Cancel
	let requireResponse: Bool
	let deviceToken: String

	init?(installation: InstallationDataService, mmContext: MobileMessaging, requireResponse: Bool, finishBlock: ((FetchInstanceDataResult) -> Void)?) {
		self.installation = installation
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = requireResponse
		self.attributesSet = []
		if let deviceToken = installation.deviceToken  {
			self.deviceToken = deviceToken
		} else {
			MMLogWarn("[CreateInstanceOperation] There is no device token. Aborting...")
			return nil
		}
	}

	override func execute() {
		attributesSet = installation.dirtyAttributesAll
		guard !isCancelled else {
			MMLogDebug("[CreateInstanceOperation] cancelled...")
			finish()
			return
		}
		if !attributesSet.contains(.pushServiceToken) {
			MMLogDebug("[CreateInstanceOperation] There is no change for device token. Aborting...")
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

		mmContext.remoteApiProvider.postInstance(applicationCode: mmContext.applicationCode, body: InstallationDataMapper.requestPayload(with: installation, forAttributesSet: attributesSet) ?? [:]) { (result) in
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
			if response.pushRegistrationId != installation.pushRegistrationId {
				// this is to force system data sync for the new registration
				installation.systemDataHash = 0
			}
			installation.pushRegistrationId = response.pushRegistrationId
			installation.isPushRegistrationEnabled = response.isPushRegistrationEnabled
			installation.persist()
			installation.resetNeedToSync(attributesSet: attributesSet)
			installation.persist()
			UserEventsManager.postInstallationSyncedEvent(installation.dataObject)
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
