//
//  FetchInstanceOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 09/11/2018.
//

import Foundation

class FetchInstanceOperation : MMOperation {
	
	let mmContext: MobileMessaging
	let currentInstallation: MMInstallation
	let finishBlock: ((NSError?) -> Void)
	let pushRegistrationId: String

    init?(userInitiated: Bool, currentInstallation: MMInstallation, mmContext: MobileMessaging, finishBlock: @escaping ((NSError?) -> Void)) {
		self.currentInstallation = currentInstallation
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		if let pushRegistrationId = currentInstallation.pushRegistrationId {
			self.pushRegistrationId = pushRegistrationId
		} else {
			Self.logDebug("There is no registration. Abortin...")
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
        mmContext.remoteApiProvider.getInstance(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId, queue: underlyingQueue) { (result) in
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
		case .Success(let responseInstallation):
			if fetchedInstallationMayBeSaved(fetchedInstallation: responseInstallation) {
				responseInstallation.archiveAll()
			}
			logDebug("successfully synced")
		case .Failure(let error):
			logError("sync request failed with error: \(error.orNil)")
		case .Cancel:
			logWarn("sync request cancelled.")
		}
	}

	private func fetchedInstallationMayBeSaved(fetchedInstallation: MMInstallation) -> Bool {
		return fetchedInstallation.pushRegistrationId == mmContext.dirtyInstallation().pushRegistrationId
	}

	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		finishBlock(errors.first) //check what to do with errors/
	}
}
