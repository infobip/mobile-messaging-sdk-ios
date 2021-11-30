//
//  PersonalizeOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 17/01/2019.
//

import Foundation

class PersonalizeOperation: MMOperation {
	
	let mmContext: MobileMessaging
	let userIdentity: MMUserIdentity
	let userAttributes: MMUserAttributes?
	let finishBlock: ((NSError?) -> Void)?
	let requireResponse: Bool
	let forceDepersonalize: Bool

    init(userInitiated: Bool, forceDepersonalize: Bool, userIdentity: MMUserIdentity, userAttributes: MMUserAttributes?, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)?) {
		self.forceDepersonalize = forceDepersonalize
		self.userIdentity = userIdentity
		self.userAttributes = userAttributes
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = false
		super.init(isUserInitiated: userInitiated)
	}

	override func execute() {
		guard !isCancelled else {
			logDebug("cancelled...")
			finish()
			return
		}
		logDebug("started...")
		if forceDepersonalize {
			DepersonalizeOperation.depersonalizeSubservices(mmContext: mmContext)
		}

		sendServerRequestIfNeeded()
	}

	private func sendServerRequestIfNeeded() {
		guard let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			logWarn("there is no registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		
		let body = UserDataMapper.personalizeRequestPayload(userIdentity: userIdentity, userAttributes: userAttributes) ?? [:]

		logDebug("sending request with force depersonalizing \(forceDepersonalize)")
		mmContext.remoteApiProvider.personalize(applicationCode: mmContext.applicationCode,
												pushRegistrationId: pushRegistrationId,
												body: body,
												forceDepersonalize: forceDepersonalize,
                                                queue: underlyingQueue)
		{ (result) in
			self.handlePersonalizeResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handlePersonalizeResult(_ result: PersonalizeResult) {
		guard !isCancelled else {
			logDebug("cancelled")
			return
		}

		switch result {
		case .Success:
			logDebug("succeeded with force depersonalizing \(forceDepersonalize)")
			if forceDepersonalize {
				DepersonalizeOperation.handleSuccessfulDepersonalize(mmContext: self.mmContext)
			}
			self.handleSuccessfulPersonalize(result.value)
		case .Failure(let error):
			logError("failed with force depersonalizing \(forceDepersonalize) with error: \(error.orNil)")
			if let error = error {
				if error.mm_code == "AMBIGUOUS_PERSONALIZE_CANDIDATES" || error.mm_code == "USER_MERGE_INTERRUPTED" {
					rollbackUserIdentity()
				} else {
					if forceDepersonalize {
						DepersonalizeOperation.handleFailedDepersonalize(mmContext: self.mmContext)
					}
				}
			}
		case .Cancel:
			logWarn("cancelled")
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

	private func handleSuccessfulPersonalize(_ user: MMUser?) {
		if let user = user {
			user.archiveAll()
		}
		UserEventsManager.postPersonalizedEvent()
	}

	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
        self.finishBlock?(errors.first)
	}
}
