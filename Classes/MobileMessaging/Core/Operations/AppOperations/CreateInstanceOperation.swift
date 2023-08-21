//
//  CreateInstanceOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 12/11/2018.
//

import Foundation

class CreateInstanceOperation : MMOperation {
	
	let mmContext: MobileMessaging
	let currentInstallation: MMInstallation
	let dirtyInstallation: MMInstallation
	let finishBlock: ((NSError?) -> Void)
	let requireResponse: Bool
	let body: [String: Any]

    init?(userInitiated: Bool, currentInstallation: MMInstallation, dirtyInstallation: MMInstallation, mmContext: MobileMessaging, requireResponse: Bool, finishBlock: @escaping ((NSError?) -> Void)) {
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = requireResponse
		self.currentInstallation = currentInstallation
		self.dirtyInstallation = dirtyInstallation
        
		if (dirtyInstallation.pushServiceToken == nil ||
            dirtyInstallation.pushServiceType == nil ||
			currentInstallation.pushServiceToken == dirtyInstallation.pushServiceToken)
		{
			Self.logWarn("There is no registration data to send. Aborting...")
			return nil
		}

		self.body = InstallationDataMapper.postRequestPayload(dirtyInstallation: dirtyInstallation, internalData: mmContext.internalData())
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
        mmContext.remoteApiProvider.postInstance(applicationCode: mmContext.applicationCode, body: body, queue: self.underlyingQueue) { (result) in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: FetchInstanceDataResult) {
        assert(!Thread.isMainThread)
		guard !isCancelled else {
			logDebug("cancelled.")
			return
		}
		switch result {
		case .Success(let response):
			if response.pushRegistrationId != currentInstallation.pushRegistrationId {
				// this is to force system data sync for the new registration
				let id = mmContext.internalData()
				id.registrationDate = id.registrationDate ?? MobileMessaging.date.now
				id.systemDataHash = 0
				id.archiveCurrent()
			}

			response.archiveAll()

			UserEventsManager.postInstallationSyncedEvent(currentInstallation)
			if mmContext.keychain.pushRegId == nil {
				mmContext.keychain.pushRegId = response.pushRegistrationId
			}
			logDebug("successfully created registration \(String(describing: response.pushRegistrationId))")
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
