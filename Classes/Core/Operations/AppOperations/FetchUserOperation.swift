//
//  FetchUserAttributesOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2018.
//

import Foundation

class FetchUserOperation: MMOperation {
	
	let mmContext: MobileMessaging
	let user: MMUser
	let dirtyUserVersion: Int
	let finishBlock: ((NSError?) -> Void)

    init(userInitiated: Bool, currentUser: MMUser, dirtyUser: MMUser?, mmContext: MobileMessaging, finishBlock: @escaping ((NSError?) -> Void)) {
		self.user = currentUser
		self.dirtyUserVersion = dirtyUser?.version ?? 0
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		super.init(isUserInitiated: userInitiated)
		self.addCondition(HealthyRegistrationCondition(mmContext: mmContext))
		self.addCondition(NotPendingDepersonalizationCondition(mmContext: mmContext))
	}

	override func execute() {
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
		logDebug("Started...")

		performRequest(pushRegistrationId: pushRegistrationId)
	}

	private func performRequest(pushRegistrationId: String) {
		logDebug("fetching from server...")
        mmContext.remoteApiProvider.getUser(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId, queue: underlyingQueue)
		{ result in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: FetchUserDataResult) {
        assert(!Thread.isMainThread)
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
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		finishBlock(errors.first) //check what to do with errors/
	}
}
