//
//  SaveIntanceOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 09/11/2018.
//

import Foundation

class UpdateInstanceOperation : MMOperation {
	
	let mmContext: MobileMessaging
	let currentInstallation: MMInstallation
	let body: RequestBody
	let finishBlock: ((NSError?) -> Void)
	let requireResponse: Bool
	let registrationPushRegIdToUpdate: String
	let authPushRegistrationId: String
	let dirtyInstallation: MMInstallation

    init?(userInitiated: Bool, currentInstallation: MMInstallation, dirtyInstallation: MMInstallation?, registrationPushRegIdToUpdate: String?, mmContext: MobileMessaging, requireResponse: Bool, finishBlock: @escaping ((NSError?) -> Void)) {
		self.currentInstallation = currentInstallation
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = requireResponse

		if let dirtyInstallation = dirtyInstallation {
			self.dirtyInstallation = dirtyInstallation
			self.body = InstallationDataMapper.patchRequestPayload(currentInstallation: currentInstallation, dirtyInstallation: dirtyInstallation, internalData: mmContext.internalData())
			if self.body.isEmpty {
				Self.logWarn("There is no data to send. Aborting...")
				return nil
			}
		} else {
			Self.logDebug("There are no attributes to sync save. Aborting...")
			return nil
		}

		if let registrationPushRegIdToUpdate = registrationPushRegIdToUpdate {
			self.registrationPushRegIdToUpdate = registrationPushRegIdToUpdate
		} else {
			Self.logWarn("There is no reference registration. Aborting...")
			return nil
		}

		if let authPushRegistrationId = currentInstallation.pushRegistrationId  {
			self.authPushRegistrationId = authPushRegistrationId
		} else {
			Self.logWarn("There is no authentication registration. Aborting...")
			return nil
		}
        super.init(isUserInitiated: userInitiated)
		self.addCondition(HealthyRegistrationCondition(mmContext: mmContext))
	}

	override func execute() {
		guard !isCancelled else {
			logDebug("cancelled...")
			finish()
			return
		}
		logDebug("started...")
		performRequest()
	}

	private func performRequest() {
        mmContext.remoteApiProvider.patchInstance(applicationCode: mmContext.applicationCode, authPushRegistrationId: authPushRegistrationId, refPushRegistrationId: registrationPushRegIdToUpdate, body: body, queue: underlyingQueue) { (result) in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: UpdateInstanceDataResult) {
        assert(!Thread.isMainThread)
		guard authPushRegistrationId == registrationPushRegIdToUpdate else {
			logDebug("updated other installation, no need to persist data. Finishing.")
			return
		}
		guard !isCancelled else {
			logDebug("cancelled.")
			return
		}
		switch result {
		case .Success:

			let id = mmContext.internalData()
			id.systemDataHash = Int64(MobileMessaging.userAgent.systemData.stableHashValue)
			id.registrationDate = id.registrationDate ?? MobileMessaging.date.now
			id.archiveCurrent()

			dirtyInstallation.archiveCurrent()

			UserEventsManager.postInstallationSyncedEvent(mmContext.currentInstallation())
			logDebug("successfully synced")
		case .Failure(let error):
			logError("sync request failed with error: \(error.orNil)")
		case .Cancel:
			logWarn("sync request cancelled.")
		}
	}

	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		finishBlock(errors.first)
	}
}
