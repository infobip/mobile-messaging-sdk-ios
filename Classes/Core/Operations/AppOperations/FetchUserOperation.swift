//
//  FetchUserAttributesOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2018.
//

import Foundation

class FetchUserOperation: MMOperation {
	
	let mmContext: MobileMessaging
	let user: User
	let dirtyUserVersion: Int
	let finishBlock: ((NSError?) -> Void)

	init(currentUser: User, dirtyUser: User?, mmContext: MobileMessaging, finishBlock: @escaping ((NSError?) -> Void)) {
		self.user = currentUser
		self.dirtyUserVersion = dirtyUser?.version ?? 0
		self.mmContext = mmContext
		self.finishBlock = finishBlock
	}

	override func execute() {
		guard mmContext.internalData().currentDepersonalizationStatus != .pending else {
			logWarn("Logout pending. Canceling...")
			finishWithError(NSError(type: MMInternalErrorType.PendingLogout))
			return
		}
		guard !isCancelled else {
			logDebug("cancelled...")
			finish()
			return
		}
		guard let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			logWarn("There is no registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			logWarn("Registration is not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.InvalidRegistration))
			return
		}
		logDebug("Started...")

		performRequest(pushRegistrationId: pushRegistrationId)
	}

	private func performRequest(pushRegistrationId: String) {
		logDebug("fetching from server...")
		mmContext.remoteApiProvider.getUser(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId)
		{ result in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: FetchUserDataResult) {
		guard !isCancelled else {
			logDebug("cancelled.")
			return
		}

		switch result {
		case .Success(let responseUser):
			if self.dirtyUserVersion != mmContext.dirtyUser().version {
				return
			}
			responseUser.archiveAll()

			logDebug("successfully synced")
		case .Failure(let error):
			logError("sync request failed with error: \(error.orNil)")
			return
		case .Cancel:
			logWarn("sync request cancelled.")
			return
		}
	}

	override func finished(_ errors: [NSError]) {
		logDebug("finished with errors: \(errors)")
		finishBlock(errors.first) //check what to do with errors/
	}
}
