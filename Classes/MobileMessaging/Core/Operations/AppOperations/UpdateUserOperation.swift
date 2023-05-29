//
//  SaveUserAttributeOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01/11/2018.
//

import Foundation

class UpdateUserOperation: MMOperation {

	let mmContext: MobileMessaging
	let finishBlock: ((NSError?) -> Void)
	let requireResponse: Bool
	let body: RequestBody
	let dirtyUser: MMUser

    init?(userInitiated: Bool, currentUser: MMUser, dirtyUser: MMUser?, mmContext: MobileMessaging, requireResponse: Bool, finishBlock: @escaping ((NSError?) -> Void)) {
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = requireResponse

		if let dirtyUser = dirtyUser {
			self.dirtyUser = dirtyUser
            if let b = UserDataMapper.requestPayload(currentUser: currentUser, dirtyUser: dirtyUser) {
                self.body = b
            } else {
                Self.logWarn("There is no data to send. Aborting...")
                return nil
            }

		} else {
			Self.logDebug("There are no attributes to sync save. Aborting...")
			return nil
		}
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
		logDebug("started...")
		performRequest(pushRegistrationId: pushRegistrationId)
	}

	private func performRequest(pushRegistrationId: String) {
		mmContext.remoteApiProvider.patchUser(applicationCode: mmContext.applicationCode,
											  pushRegistrationId: pushRegistrationId,
											  body: body,
                                              queue: underlyingQueue)
		{ (result) in
			self.handleUserDataUpdateResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handleUserDataUpdateResult(_ result: UpdateUserDataResult) {
        assert(!Thread.isMainThread)
		guard !isCancelled else {
			logDebug("cancelled.")
			return
		}

		switch result {
		case .Success:
			dirtyUser.archiveCurrent()
			UserEventsManager.postUserSyncedEvent(MobileMessaging.currentUser)
			logDebug("successfully synced")
		case .Failure(let error):
			if error?.mm_code == "USER_MERGE_INTERRUPTED" {
				rollbackUserIdentity()
			}
			logError("sync request failed with error: \(error.orNil)")
		case .Cancel:
			logWarn("sync request cancelled.")
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
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		finishBlock(errors.first)
	}
}
