//
//  FetchInstanceOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 09/11/2018.
//

import Foundation

class FetchInstanceOperation : MMOperation {
	
	let mmContext: MobileMessaging
	let currentInstallation: Installation
	let finishBlock: ((NSError?) -> Void)
	let pushRegistrationId: String

	init?(currentInstallation: Installation, mmContext: MobileMessaging, finishBlock: @escaping ((NSError?) -> Void)) {
		self.currentInstallation = currentInstallation
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		if let pushRegistrationId = currentInstallation.pushRegistrationId {
			self.pushRegistrationId = pushRegistrationId
		} else {
			Self.logDebug("There is no registration. Abortin...")
			return nil
		}
	}

	override func execute() {
		guard !isCancelled else {
			logDebug("cancelled...")
			finish()
			return
		}
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			logWarn("Registration is not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.InvalidRegistration))
			return
		}
		logDebug("started...")
		performRequest()
	}

	private func performRequest() {
		mmContext.remoteApiProvider.getInstance(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId) { (result) in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: FetchInstanceDataResult) {
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

	private func fetchedInstallationMayBeSaved(fetchedInstallation: Installation) -> Bool {
		return fetchedInstallation.pushRegistrationId == mmContext.dirtyInstallation().pushRegistrationId
	}

	override func finished(_ errors: [NSError]) {
		logDebug("finished with errors: \(errors)")
		finishBlock(errors.first) //check what to do with errors/
	}
}
