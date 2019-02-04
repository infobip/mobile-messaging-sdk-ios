//
//  PersonalizeOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 17/01/2019.
//

import Foundation

class PersonalizeOperation: Operation {
	let mmContext: MobileMessaging
	let userIdentity: UserIdentity
	let userAttributes: UserAttributes?
	let finishBlock: ((PersonalizeResult) -> Void)?
	var result: PersonalizeResult = PersonalizeResult.Cancel
	let requireResponse: Bool
	let forceDepersonalize: Bool

	init?(forceDepersonalize: Bool, userIdentity: UserIdentity, userAttributes: UserAttributes?, mmContext: MobileMessaging, finishBlock: ((PersonalizeResult) -> Void)?) {
		self.forceDepersonalize = forceDepersonalize
		self.userIdentity = userIdentity
		self.userAttributes = userAttributes
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = false
	}

	override func execute() {
		guard !isCancelled else {
			MMLogDebug("[PersonalizeOperation] cancelled...")
			finish()
			return
		}
		MMLogDebug("[PersonalizeOperation] started...")
		if forceDepersonalize {
			DepersonalizeOperation.depersonalizeSubservices(mmContext: mmContext)
		}

		sendServerRequestIfNeeded()
	}

	private func sendServerRequestIfNeeded() {
		guard let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			MMLogWarn("[PersonalizeOperation] there is no registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		
		let body = UserDataMapper.personalizeRequestPayload(userIdentity: userIdentity, userAttributes: userAttributes) ?? [:]

		MMLogDebug("[PersonalizeOperation] sending request with force depersonalizing \(forceDepersonalize)")
		mmContext.remoteApiProvider.personalize(applicationCode: mmContext.applicationCode,
												pushRegistrationId: pushRegistrationId,
												body: body,
												forceDepersonalize: forceDepersonalize)
		{ (result) in
			self.handlePersonalizeResult(result)
			self.finishWithError(result.error)
		}
	}

	private func handlePersonalizeResult(_ result: PersonalizeResult) {
		self.result = result
		guard !isCancelled else {
			MMLogDebug("[PersonalizeOperation] cancelled")
			return
		}

		switch result {
		case .Success:
			MMLogDebug("[PersonalizeOperation] succeeded with force depersonalizing \(forceDepersonalize)")
			if forceDepersonalize {
				DepersonalizeOperation.handleSuccessfulDepersonalize(mmContext: self.mmContext)
			}
			self.handleSuccessfulPersonalize(result.value)
		case .Failure(let error):
			MMLogError("[PersonalizeOperation] failed with force depersonalizing \(forceDepersonalize) with error: \(error.orNil)")
			if error?.mm_code == "USER_MERGE_INTERRUPTED" {
				rollbackUserIdentity()
			}
			if forceDepersonalize {
				DepersonalizeOperation.handleFailedDepersonalize(mmContext: self.mmContext)
			}
		case .Cancel:
			MMLogWarn("[PersonalizeOperation] cancelled")
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

	private func handleSuccessfulPersonalize(_ user: User?) {
		if let user = user {
			user.archiveAll()
		}
		UserEventsManager.postPersonalizedEvent()
	}

	override func finished(_ errors: [NSError]) {
		MMLogDebug("[PersonalizeOperation] finished with errors: \(errors)")
		finishBlock?(self.result)
	}
}
