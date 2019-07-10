//
//  FetchUserAttributesOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2018.
//

import Foundation

class FetchUserOperation: Operation {
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
			MMLogWarn("[FetchUserOperation] Logout pending. Canceling...")
			finishWithError(NSError(type: MMInternalErrorType.PendingLogout))
			return
		}
		guard !isCancelled else {
			MMLogDebug("[FetchUserOperation] cancelled...")
			finish()
			return
		}
		guard let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			MMLogWarn("[FetchUserOperation] There is no registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogWarn("[FetchUserOperation] Registration is not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.InvalidRegistration))
			return
		}
		MMLogDebug("[FetchUserOperation] Started...")

		performRequest(pushRegistrationId: pushRegistrationId)
	}

	private func performRequest(pushRegistrationId: String) {
		MMLogDebug("[FetchUserOperation] fetching from server...")
		mmContext.remoteApiProvider.getUser(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId)
		{ result in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleResult(_ result: FetchUserDataResult) {
		guard !isCancelled else {
			MMLogDebug("[FetchUserOperation] cancelled.")
			return
		}

		switch result {
		case .Success(let responseUser):
			if self.dirtyUserVersion != mmContext.dirtyUser().version {
				return
			}
			responseUser.archiveAll()

			MMLogDebug("[FetchUserOperation] successfully synced")
		case .Failure(let error):
			MMLogError("[FetchUserOperation] sync request failed with error: \(error.orNil)")
			return
		case .Cancel:
			MMLogWarn("[FetchUserOperation] sync request cancelled.")
			return
		}
	}

	override func finished(_ errors: [NSError]) {
		MMLogDebug("[FetchUserOperation] finished with errors: \(errors)")
		finishBlock(errors.first) //check what to do with errors/
	}
}
