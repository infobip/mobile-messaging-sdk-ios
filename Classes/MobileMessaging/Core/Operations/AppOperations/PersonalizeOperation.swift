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
	/// The request body, built when personalize was called (`UserDataService.personalize`).
	let requestBody: RequestBody
	let finishBlock: ((_ error: NSError?, _ succeeded: Bool) -> Void)?
	private var didSucceed = false
	/// Identifies identical personalize calls (see `UserDataService.personalize`).
	let debounceKey: [String: Any]
	/// Taken when the operation runs, so an identical personalize queued before this one has finished by then.
	private var debounceTicket: MMDebouncingGuard.Ticket?
	let requireResponse: Bool
	let forceDepersonalize: Bool
    let keepAsLead: Bool
    let setDeviceAsPrimary: Bool

    init(userInitiated: Bool, forceDepersonalize: Bool, keepAsLead: Bool, setDeviceAsPrimary: Bool, requestBody: RequestBody, mmContext: MobileMessaging, debounceKey: [String: Any], finishBlock: ((_ error: NSError?, _ succeeded: Bool) -> Void)?) {
		self.forceDepersonalize = forceDepersonalize
		self.debounceKey = debounceKey
        self.keepAsLead = keepAsLead
        self.setDeviceAsPrimary = setDeviceAsPrimary
		self.requestBody = requestBody
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
		// The queue is serial: an identical personalize that was in flight when this one was called has finished
		// by now. If it succeeded, this one is a duplicate. Checked before the forced cleanup, so a duplicate forced
		// personalize does not clean up the subservices again.
		guard let ticket = mmContext.debouncingGuard.admit(.personalize, data: debounceKey) else {
			logDebug("identical personalize succeeded meanwhile, not sent")
			finish()
			return
		}
		debounceTicket = ticket
		logDebug("started...")
		if forceDepersonalize {
			// part of this very personalize call: its own debounce entry stays
			DepersonalizeOperation.depersonalizeSubservices(userInitiated: userInitiated, mmContext: mmContext, keepingDebounceOf: .personalize)
			// cleanup can take a while: the SDK may have been stopped (and this operation cancelled) meanwhile
			guard !isCancelled else {
				logDebug("cancelled during depersonalization...")
				finish()
				return
			}
		}

		sendServerRequestIfNeeded()
	}

	private func sendServerRequestIfNeeded() {
		guard let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			logWarn("there is no registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		
		let body = requestBody
        
        var accessToken: String? = nil
        do {
            accessToken = try mmContext.getValidJwtAccessToken()
        } catch let error as NSError {
            finishWithError(error)
            return
        }
        
        logDebug("Sending personalize API request - Auth: \(accessToken != nil ? "JWT" : "AppCode"), forceDeperosnalize: \(forceDepersonalize)")
		// stop() releases the provider; never unwrap it implicitly here
		guard let remoteApiProvider = mmContext.remoteApiProvider as RemoteAPIProvider? else {
			logWarn("SDK was stopped. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.MobileMessagingInstanceNotInitialized))
			return
		}
		remoteApiProvider.personalize(applicationCode: mmContext.applicationCode,
                                                accessToken: accessToken,
												pushRegistrationId: pushRegistrationId,
												body: body,
                                                forceDepersonalize: forceDepersonalize,
                                                keepAsLead: keepAsLead,
                                                setDeviceAsPrimary: setDeviceAsPrimary,
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
			didSucceed = true
			logDebug("succeeded with force depersonalizing \(forceDepersonalize)")
			if forceDepersonalize {
				DepersonalizeOperation.handleSuccessfulDepersonalize(mmContext: self.mmContext, keepingDebounceOf: .personalize)
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
        debounceTicket.map { mmContext.debouncingGuard.finish($0, succeeded: didSucceed) }
        self.finishBlock?(errors.first, didSucceed)
	}
}
