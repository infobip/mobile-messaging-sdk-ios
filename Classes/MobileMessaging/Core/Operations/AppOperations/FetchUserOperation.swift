// 
//  FetchUserOperation.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class FetchUserOperation: MMOperation {
	
	let mmContext: MobileMessaging
	let user: MMUser
	/// `MMUser.dirtyRevision` when the request was sent: a change of the dirty user during the request discards
	/// the response. Taken when the request starts, not when the operation is queued: earlier operations on the
	/// queue (e.g. another fetch) apply their responses meanwhile, which are not local changes.
	private var revisionAtRequest: UInt64 = 0
	let finishBlock: ((_ error: NSError?, _ succeeded: Bool) -> Void)
	private var didSucceed = false

    init(userInitiated: Bool, currentUser: MMUser, mmContext: MobileMessaging, finishBlock: @escaping ((_ error: NSError?, _ succeeded: Bool) -> Void)) {
		self.user = currentUser
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
		revisionAtRequest = MMUser.dirtyRevision
		performRequest(pushRegistrationId: pushRegistrationId)
	}

	private func performRequest(pushRegistrationId: String) {
        var accessToken: String? = nil
        do {
            accessToken = try mmContext.getValidJwtAccessToken()
        } catch let error as NSError {
            finishWithError(error)
            return
        }
        
        logDebug("Fetching from server - Auth: \(accessToken != nil ? "JWT" : "AppCode")")
        mmContext.remoteApiProvider.getUser(applicationCode: mmContext.applicationCode, accessToken: accessToken, pushRegistrationId: pushRegistrationId, queue: underlyingQueue)
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
			// A discarded response did not refresh anything, so it is not a success.
			if revisionAtRequest != MMUser.dirtyRevision {
				logDebug("local user data changed during fetch, response discarded")
				return
			}
			if hasUnsyncedLocalChanges && UserDataService.hasPendingUserWrite() {
				// e.g. a save made while this fetch was queued, still waiting to be sent: the response would overwrite
				// it. Without a pending write (e.g. the server rejected the save) the server data is applied as before.
				logDebug("local user data not synced yet, response discarded")
				return
			}
			responseUser.archiveAll()
			didSucceed = true // only once the response is actually applied

			logDebug("successfully synced")
		case .Failure(let error):
			logError("sync request failed with error: \(error.orNil)")
			return
		case .Cancel:
			logWarn("sync request cancelled.")
			return
		}
	}

	/// The dirty user differs from the server-confirmed one in data a save sends. `requestPayload` returns `[:]`
	/// when only stripped fields (installations, type) differ, which is not an unsynced change.
	private var hasUnsyncedLocalChanges: Bool {
		return UserDataMapper.requestPayload(currentUser: mmContext.currentUser(), dirtyUser: mmContext.dirtyUser())?.isEmpty == false
	}

	override func finished(_ errors: [NSError]) {
        logDebug("finished with errors: \(errors)")
		finishBlock(errors.first, didSucceed)
	}
}
