// 
//  UpdateUserOperation.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class UpdateUserOperation: MMOperation {

	let mmContext: MobileMessaging
	let finishBlock: ((_ error: NSError?, _ succeeded: Bool) -> Void)
	private var didSucceed = false
	let requireResponse: Bool
	/// The user as requested when this operation was created.
	let dirtyUser: MMUser
	/// The fields this write changes (see `UserDataMapper.changedFields`). Only these are sent: the rest of the
	/// snapshot may be outdated by the time the operation runs (e.g. a personalize overtook it).
	let fields: RequestBody
	/// What was sent, marked as synced on success.
	private var sentBody: RequestBody = [:]

    init?(userInitiated: Bool, dirtyUser: MMUser?, fields: RequestBody, mmContext: MobileMessaging, requireResponse: Bool, finishBlock: @escaping ((_ error: NSError?, _ succeeded: Bool) -> Void)) {
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		self.requireResponse = requireResponse
		self.fields = fields

		if let dirtyUser = dirtyUser {
			// The delta is computed in execute(): earlier writes on the serial queue may still change the
			// server state (save B pending, then save A back to the cached value must still send A).
			self.dirtyUser = dirtyUser
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
		let delta = UserDataMapper.requestPayload(currentUser: mmContext.currentUser(), dirtyUser: dirtyUser) ?? [:]
		let body = UserDataMapper.restrict(delta, to: fields)
		guard !body.isEmpty else {
			logDebug("There is no data to send. Finishing...")
			didSucceed = true // the server already has the requested state
			finish()
			return
		}
		logDebug("started...")
		sentBody = body
		performRequest(pushRegistrationId: pushRegistrationId, body: body)
	}

	private func performRequest(pushRegistrationId: String, body: RequestBody) {
        var accessToken: String? = nil
        do {
            accessToken = try mmContext.getValidJwtAccessToken()
        } catch let error as NSError {
            finishWithError(error)
            return
        }
        
        logDebug("Updating user - Auth: \(accessToken != nil ? "JWT" : "AppCode")")
		mmContext.remoteApiProvider.patchUser(applicationCode: mmContext.applicationCode,
                                              accessToken: accessToken,
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
			didSucceed = true
			markSentFieldsSynced()
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

	/// The server-confirmed user takes the sent fields from the snapshot; fields not sent keep their value. The
	/// local user is left alone: it already holds this save's values or a newer local change (e.g. persistUser,
	/// a later save, or a personalize called after this save, whose values the next sync sends).
	private func markSentFieldsSynced() {
		let sent = dirtyUser
		MMUser.modifyCurrent { Self.take(sentBody, from: sent, into: $0) }
	}

	/// Copies the fields listed in `body` (custom attributes: only its sub-keys) from `source` into `target`.
	private static func take(_ body: RequestBody, from source: MMUser, into target: MMUser) {
		for (key, value) in body {
			switch key {
			case "externalUserId": target.externalUserId = source.externalUserId
			case "phones": target.phones = source.phones
			case "emails": target.emails = source.emails
			case "firstName": target.firstName = source.firstName
			case "middleName": target.middleName = source.middleName
			case "lastName": target.lastName = source.lastName
			case "tags": target.tags = source.tags
			case "gender": target.gender = source.gender
			case "birthday": target.birthday = source.birthday
			case "customAttributes":
				if let subKeys = value as? RequestBody, !subKeys.isEmpty {
					var merged = target.customAttributes ?? [:]
					subKeys.keys.forEach { merged[$0] = source.customAttributes?[$0] }
					target.customAttributes = merged
				} else {
					target.customAttributes = source.customAttributes
				}
			default:
				logWarn("unexpected user field \(key) sent")
			}
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
        logDebug("finished with errors: \(errors)")
		finishBlock(errors.first, didSucceed)
	}
}
