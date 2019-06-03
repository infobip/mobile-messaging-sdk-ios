//
//  SaveUserAttributeOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01/11/2018.
//

import Foundation

class UpdateUserOperation: Operation {
	let mmContext: MobileMessaging
	let finishBlock: ((NSError?) -> Void)
	let requireResponse: Bool
	let body: RequestBody
	let dirtyUser: User

	init?(currentUser: User, dirtyUser: User?, mmContext: MobileMessaging, requireResponse: Bool, finishBlock: @escaping ((NSError?) -> Void)) {
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = requireResponse

		if let dirtyUser = dirtyUser {
			self.dirtyUser = dirtyUser
			self.body = UserDataMapper.requestPayload(currentUser: currentUser, dirtyUser: dirtyUser)
			if self.body.isEmpty {
				MMLogWarn("[UpdateUserOperation] There is no data to send. Aborting...")
				return nil
			}
		} else {
			MMLogDebug("[UpdateUserOperation] There are no attributes to sync save. Aborting...")
			return nil
		}
	}

	override func execute() {
		guard mmContext.internalData().currentDepersonalizationStatus != .pending else {
			MMLogWarn("[UpdateUserOperation] Logout pending. Canceling...")
			finishWithError(NSError(type: MMInternalErrorType.PendingLogout))
			return
		}
		guard !isCancelled else {
			MMLogDebug("[UpdateUserOperation] cancelled...")
			finish()
			return
		}
		MMLogDebug("[UpdateUserOperation] started...")
		sendServerRequestIfNeeded()
	}

	private func sendServerRequestIfNeeded() {
		guard let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			MMLogWarn("[UpdateUserOperation] There is no registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogWarn("[UpdateUserOperation] Registration is not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.InvalidRegistration))
			return
		}

		mmContext.remoteApiProvider.patchUser(applicationCode: mmContext.applicationCode,
											  pushRegistrationId: pushRegistrationId,
											  body: body)
		{ (result) in
			self.handleUserDataUpdateResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleUserDataUpdateResult(_ result: UpdateUserDataResult) {
		guard !isCancelled else {
			MMLogDebug("[UpdateUserOperation] cancelled.")
			return
		}

		switch result {
		case .Success:
			dirtyUser.archiveCurrent()
			UserEventsManager.postUserSyncedEvent(MobileMessaging.currentUser)
			MMLogDebug("[UpdateUserOperation] successfully synced")
		case .Failure(let error):
			if error?.mm_code == "USER_MERGE_INTERRUPTED" {
				rollbackUserIdentity()
			}
			MMLogError("[UpdateUserOperation] sync request failed with error: \(error.orNil)")
		case .Cancel:
			MMLogWarn("[UpdateUserOperation] sync request cancelled.")
		}
	}

	private func rollbackUserIdentity() {
		let currentUser = mmContext.currentUser()
		let dirtyUser = mmContext.dirtyUser()
		dirtyUser.phones = currentUser.phones
		dirtyUser.emails = currentUser.emails
		dirtyUser.externalUserId = currentUser.externalUserId
		dirtyUser.archiveDirty()
	}

	override func finished(_ errors: [NSError]) {
		MMLogDebug("[UpdateUserOperation] finished with errors: \(errors)")
		finishBlock(errors.first)
	}
}
