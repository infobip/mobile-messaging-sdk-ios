// 
//  PersonalizeOperation.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class PersonalizeOperation: MMOperation {
	
	let mmContext: MobileMessaging
	let userIdentity: MMUserIdentity
	let userAttributes: MMUserAttributes?
	let finishBlock: ((NSError?) -> Void)?
	let requireResponse: Bool
	let forceDepersonalize: Bool
    let keepAsLead: Bool

    init(userInitiated: Bool, forceDepersonalize: Bool, keepAsLead: Bool, userIdentity: MMUserIdentity, userAttributes: MMUserAttributes?, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)?) {
		self.forceDepersonalize = forceDepersonalize
        self.keepAsLead = keepAsLead
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
			DepersonalizeOperation.depersonalizeSubservices(userInitiated: userInitiated, mmContext: mmContext)
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
        
        var accessToken: String? = nil
        do {
            accessToken = try mmContext.getValidJwtAccessToken()
        } catch let error as NSError {
            finishWithError(error)
            return
        }
        
        logDebug("Sending personalize API request - Auth: \(accessToken != nil ? "JWT" : "AppCode"), forceDeperosnalize: \(forceDepersonalize)")
		mmContext.remoteApiProvider.personalize(applicationCode: mmContext.applicationCode,
                                                accessToken: accessToken,
												pushRegistrationId: pushRegistrationId,
												body: body,
                                                forceDepersonalize: forceDepersonalize, 
                                                keepAsLead: keepAsLead,
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
        logDebug("finished with errors: \(errors)")
        self.finishBlock?(errors.first)
	}
}
