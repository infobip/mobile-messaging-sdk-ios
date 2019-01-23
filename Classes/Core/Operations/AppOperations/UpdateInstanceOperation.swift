//
//  SaveIntanceOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 09/11/2018.
//

import Foundation

class UpdateInstanceOperation : Operation {
	let mmContext: MobileMessaging
	let installation: InstallationDataService
	var attributesSet: AttributesSet
	let finishBlock: ((UpdateInstanceDataResult) -> Void)?
	var result: UpdateInstanceDataResult = UpdateInstanceDataResult.Cancel
	let requireResponse: Bool
	let registrationPushRegIdToUpdate: String
	let authPushRegistrationId: String

	init?(installation: InstallationDataService, registrationPushRegIdToUpdate: String?, mmContext: MobileMessaging, requireResponse: Bool, finishBlock: ((UpdateInstanceDataResult) -> Void)?) {
		self.installation = installation
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = requireResponse
		self.attributesSet = []
		if let registrationPushRegIdToUpdate = registrationPushRegIdToUpdate {
			self.registrationPushRegIdToUpdate = registrationPushRegIdToUpdate
		} else {
			MMLogWarn("[UpdateInstanceOperation] There is no reference registration. Aborting...")
			return nil
		}
		if let authPushRegistrationId = installation.pushRegistrationId  {
			self.authPushRegistrationId = authPushRegistrationId
		} else {
			MMLogWarn("[UpdateInstanceOperation] There is no authentication registration. Aborting...")
			return nil
		}
	}

	override func execute() {
		let systemDataAtts = ((installation.systemDataHash != Int64(MobileMessaging.userAgent.systemData.hashValue)) ? [Attributes.systemDataHash] : [])
		attributesSet = installation.dirtyAttributesAll.union(systemDataAtts)
		guard !isCancelled else {
			MMLogDebug("[UpdateInstanceOperation] cancelled...")
			finish()
			return
		}
		if attributesSet.isEmpty {
			MMLogDebug("[UpdateInstanceOperation] There are no attributes to sync save. Aborting...")
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
		if let body = InstallationDataMapper.requestPayload(with: installation, forAttributesSet: attributesSet) {
			mmContext.remoteApiProvider.patchInstance(applicationCode: mmContext.applicationCode, authPushRegistrationId: authPushRegistrationId, refPushRegistrationId: registrationPushRegIdToUpdate, body: body) { (result) in
				self.handleResult(result)
				self.finishWithError(result.error)
			}
		} else {
			self.finish()
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
			if (attributesSet.contains(.systemDataHash)) {
				installation.systemDataHash = Int64(MobileMessaging.userAgent.systemData.hashValue)
			}
			installation.persist()
			installation.resetNeedToSync(attributesSet: attributesSet)
			installation.persist()
			UserEventsManager.postInstallationSyncedEvent(installation.dataObject)
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
