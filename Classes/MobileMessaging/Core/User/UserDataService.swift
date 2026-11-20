// 
//  UserDataService.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class UserDataService: MobileMessagingService {

	init(mmContext: MobileMessaging) {
		super.init(mmContext: mmContext, uniqueIdentifier: "UserDataService")
	}

    func setInstallation(withPushRegistrationId pushRegId: String, asPrimary primary: Bool, completion: @escaping ([MMInstallation]?, NSError?) -> Void) {
        assert(!Thread.isMainThread)
        mmContext.debouncingGuard.invalidate(after: .primaryDevice)
        
		let finish: (NSError?) -> Void = { [weak self] (error) in
            guard let _self = self else {
                completion(nil, nil)
                return
            }
			if error == nil {
                _self.mmContext.debouncingGuard.invalidate(after: .primaryDevice)
                let installations = _self.mmContext.resolveUser().installations
                if let idx = installations?.firstIndex(where: { $0.isPrimaryDevice == true }) {
                    installations?[idx].isPrimaryDevice = false
                }
                if let idx = installations?.firstIndex(where: { $0.pushRegistrationId == pushRegId }) {
                    installations?[idx].isPrimaryDevice = primary
                }
				MMUser.modifyAll(with: { user in
					user.installations = installations
				})
			}
            DispatchQueue.main.async {
                completion(_self.mmContext.resolveUser().installations, error)
            }
		}

		if mmContext.currentInstallation().pushRegistrationId == pushRegId {
			let ci = mmContext.currentInstallation()
			ci.isPrimaryDevice = primary
            mmContext.installationService.save(userInitiated: true, installationData: ci, completion: finish)
		} else {
			guard let authPushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
				logError("There is no registration. Finishing setting other reg primary...")
                finish(NSError(type: MMInternalErrorType.NoRegistration))
				return
			}
			let body = ["isPrimary": primary] // TODO: move this code to mapper class
            mmContext.remoteApiProvider.patchOtherInstance(applicationCode: mmContext.applicationCode, authPushRegistrationId: authPushRegistrationId, pushRegistrationId: pushRegId, body: body, queue: DispatchQueue.main) { (result) in
				switch result {
				case .Cancel :
					finish(NSError(type: MMInternalErrorType.UnknownError)) // cannot happen!
				default:
					finish(result.error)
				}
			}
		}
	}

    func depersonalizeInstallation(userInitiated: Bool, withPushRegistrationId pushRegId: String, completion: @escaping ([MMInstallation]?, NSError?) -> Void) {
        assert(!Thread.isMainThread)
        let queuedCompletion: ([MMInstallation]?, NSError?) -> Void = { installations, error in
            let completionQueue = userInitiated ? DispatchQueue.main : installationQueue.underlyingQueue!
            completionQueue.async {
                completion(installations, error)
            }
        }
		guard pushRegId != mmContext.currentInstallation().pushRegistrationId else {
			logError("Attempt to depersonalize current installation with inappropriate API. Aborting depersonalizing other oreg...")
            queuedCompletion(mmContext.resolveUser().installations, NSError(type: MMInternalErrorType.CantLogoutCurrentRegistration))
			return
		}
		guard let authPushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			logError("There is no registration. Finishing depersonalizing other reg...")
            queuedCompletion(mmContext.resolveUser().installations, NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
        guard let ticket = mmContext.debouncingGuard.admit(.depersonalizeInstallation, data: ["pushRegId": pushRegId, "registration": authPushRegistrationId]) else {
            logWarn("depersonalize installation dropped - duplicate call within debounce window")
            queuedCompletion(mmContext.resolveUser().installations, nil)
            return
        }

        mmContext.remoteApiProvider.depersonalize(applicationCode: mmContext.applicationCode, pushRegistrationId: authPushRegistrationId, pushRegistrationIdToDepersonalize: pushRegId, queue: installationQueue.underlyingQueue!) { [mmContext] (result) in
            // user storage is shared between SDK instances: once stopped, this one must not read or modify it
            guard Self.isCurrentInstance(mmContext) else {
                queuedCompletion(nil, Self.stoppedInstanceError)
                return
            }
			if result.error == nil {
				let ins = mmContext.resolveUser().installations?.filter { $0.pushRegistrationId != pushRegId }
				MMUser.modifyAll(with: { (user) in
					user.installations = ins
				})
			}
            // after the local update: a duplicate dropped from now on reads the updated installations
            mmContext.debouncingGuard.finish(ticket, succeeded: result.isSuccess)
            queuedCompletion(mmContext.resolveUser().installations, result.error)
		}
	}

    func save(userInitiated: Bool, userData: MMUser, completion: @escaping (NSError?) -> Void) {
        assert(!Thread.isMainThread)
        do {
            try UserDataValidator.validate(user: userData)
        } catch let validationError as NSError {
            completion(validationError)
            return
        }
        // Keyed on the PATCH body that will be sent, computed before archiving so a dropped save has no local
        // side effects. No body means nothing to send, so nothing to debounce.
        var ticket: MMDebouncingGuard.Ticket?
        if let payload = UserDataMapper.requestPayload(currentUser: mmContext.currentUser(), dirtyUser: userData) {
            ticket = mmContext.debouncingGuard.admit(.saveUser, data: ["payload": payload, "registration": currentRegistration])
            guard ticket != nil else {
                logWarn("save user dropped - duplicate call within debounce window")
                completion(nil)
                return
            }
        }
		// what this save changes, so a write that overtakes it (e.g. a personalize) is never undone by its snapshot
		let fields = UserDataMapper.changedFields(of: userData, currentUser: mmContext.currentUser(), previousUser: mmContext.dirtyUser())
		logDebug("saving \(userData.dictionaryRepresentation)")
		userData.archiveDirty()
        syncWithServer(userInitiated: userInitiated, ticket: ticket, fields: fields) { error, _ in completion(error) }
	}

	var isChanged: Bool {
		return MMUser.delta != nil
	}

    func personalize(userInitiated: Bool, forceDepersonalize: Bool, keepAsLead: Bool, setDeviceAsPrimary: Bool, userIdentity: MMUserIdentity, userAttributes: MMUserAttributes?, completion: @escaping (NSError?) -> Void) {
        assert(!Thread.isMainThread)

        // Validate user data before personalization
        do {
            try UserDataValidator.validate(userIdentity: userIdentity)
            try UserDataValidator.validate(userAttributes: userAttributes)
        } catch let validationError as NSError {
            completion(validationError)
            return
        }

        // built once, now: the caller may mutate userIdentity/userAttributes afterwards, so the request the queued
        // operation sends and the debounce key must both come from this snapshot
        let requestBody = UserDataMapper.personalizeRequestPayload(userIdentity: userIdentity, userAttributes: userAttributes) ?? [:]
        let debounceKey: [String: Any] = [
            "payload": requestBody,
            "forceDepersonalize": forceDepersonalize,
            "keepAsLead": keepAsLead,
            "setDeviceAsPrimary": setDeviceAsPrimary,
            "registration": currentRegistration
        ]
        // Right after an identical success: dropped here, without touching local data. If a personalize or logout is
        // still queued or running, the call is queued instead and checked when it runs (PersonalizeOperation): by
        // then everything before it has finished, e.g. A succeeded -> B queued -> A is sent after B.
        guard Self.hasPendingIdentityChange() || !mmContext.debouncingGuard.isDuplicate(.personalize, data: debounceKey) else {
            logWarn("personalize dropped - duplicate call within debounce window")
            completion(nil)
            return
        }
		mmContext.debouncingGuard.invalidate(after: .personalization, except: .personalize)

		let du = mmContext.dirtyUser()
		UserDataMapper.apply(userIdentity: userIdentity, to: du)
		if let userAttributes = userAttributes {
			UserDataMapper.apply(userAttributes: userAttributes, to: du)
		}
		du.archiveDirty()

		let op = PersonalizeOperation(
            userInitiated: userInitiated,
            forceDepersonalize: forceDepersonalize,
            keepAsLead: keepAsLead,
            setDeviceAsPrimary: setDeviceAsPrimary,
			requestBody: requestBody,
			mmContext: mmContext,
			debounceKey: debounceKey,
			finishBlock: { [mmContext] error, succeeded in
				// `succeeded` only when a request was sent and succeeded: a dropped duplicate changed nothing
				if succeeded {
					mmContext.debouncingGuard.invalidate(after: .personalization, except: .personalize)
				}
				completion(error)
			})

		op.queuePriority = .veryHigh
		installationQueue.addOperation(op)

	}

    func fetchFromServer(userInitiated: Bool, completion: @escaping (MMUser, NSError?) -> Void) {
        assert(!Thread.isMainThread)
        guard let ticket = mmContext.debouncingGuard.admit(.fetchUser, data: ["userInitiated": userInitiated, "registration": currentRegistration]) else {
            logWarn("fetch user dropped - duplicate call within debounce window")
            completion(mmContext.resolveUser(), nil)
            return
        }
		logDebug("fetch from server")
		let op = FetchUserOperation(
            userInitiated: userInitiated,
			currentUser: mmContext.currentUser(),
			mmContext: mmContext,
            finishBlock: { [mmContext] error, succeeded in
                if succeeded {
                    mmContext.debouncingGuard.invalidate(after: .fetchedUser, except: .fetchUser)
                }
                mmContext.debouncingGuard.finish(ticket, succeeded: succeeded)
                // once stopped, the shared user storage may belong to a new SDK instance
                if Self.isCurrentInstance(mmContext) {
                    completion(mmContext.resolveUser(), error)
                } else {
                    completion(MMUser.empty, error ?? Self.stoppedInstanceError)
                }
            })
		installationQueue.addOperation(op)
	}

	// MARK: - MobileMessagingService protocol {
	override func depersonalizeService(_ mmContext: MobileMessaging, userInitiated: Bool, completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
		logDebug("depersonalizing...")
		MMUser.empty.archiveAll()
		completion()
	}

	override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
        syncWithServer(userInitiated: false) {_ in completion() }
	}

	override func mobileMessagingDidStart(_ completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
        syncWithServer(userInitiated: false) {_ in completion() }
	}
    
    override func mobileMessagingWillStop(_ completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
        MMUser.cached.reset()
        completion()
    }

    func syncWithServer(userInitiated: Bool, completion: @escaping (NSError?) -> Void) {
        syncWithServer(userInitiated: userInitiated, ticket: nil, fields: nil) { error, _ in completion(error) }
    }

    /// - parameter ticket: the debounce ticket of the save this sync belongs to, if any; it is finished with
    ///   the outcome (`succeeded` is also true when there was nothing to send).
    /// - parameter fields: the fields the write sends (`nil`: everything not synced yet, as of now).
    private func syncWithServer(userInitiated: Bool, ticket: MMDebouncingGuard.Ticket?, fields: RequestBody?, completion: @escaping (_ error: NSError?, _ succeeded: Bool) -> Void) {
        assert(!Thread.isMainThread)
		logDebug("sync user data with server")
		let debouncingGuard = mmContext.debouncingGuard
		let finish: (NSError?, Bool) -> Void = { error, succeeded in
			ticket.map { debouncingGuard.finish($0, succeeded: succeeded) }
			completion(error, succeeded)
		}
		// Nothing to send now, and no earlier user write queued that could still change the server state.
		// Otherwise queue it: the operation computes its delta when its turn comes.
		let unsynced = UserDataMapper.requestPayload(currentUser: mmContext.currentUser(), dirtyUser: mmContext.dirtyUser())
		if unsynced == nil, !Self.hasPendingUserWrite() {
			finish(nil, true)
			return
		}
		guard let op = UpdateUserOperation(
            userInitiated: userInitiated,
			dirtyUser: mmContext.dirtyUser(),
			fields: fields ?? unsynced ?? [:],
			mmContext: mmContext,
			requireResponse: false,
			finishBlock: { error, succeeded in
				if succeeded {
					debouncingGuard.invalidate(after: .userData, except: ticket?.type)
				}
				finish(error, succeeded)
			})
		else {
			finish(nil, true)
			return
		}
		debouncingGuard.invalidate(after: .userData, except: ticket?.type)
		installationQueue.addOperation(op)
	}

    /// Whether a user write (save or personalize) is queued or running: it can change what a later save sends.
    static func hasPendingUserWrite() -> Bool {
        return installationQueue.operations.contains { op in
            (op is UpdateUserOperation || op is PersonalizeOperation) && !op.isFinished && !op.isCancelled
        }
    }

    /// Whether a personalize or logout is queued or running: it can change which personalize is a duplicate.
    private static func hasPendingIdentityChange() -> Bool {
        return installationQueue.operations.contains { op in
            (op is PersonalizeOperation || op is DepersonalizeOperation) && !op.isFinished && !op.isCancelled
        }
    }

    /// Whether `mmContext` is still the running SDK instance (a stop, or a stop and restart, replaces it).
    private static func isCurrentInstance(_ mmContext: MobileMessaging) -> Bool {
        return MobileMessaging.sharedInstance === mmContext
    }

    private static var stoppedInstanceError: NSError {
        return NSError(type: .MobileMessagingInstanceNotInitialized)
    }

    /// Part of every debounce key: identical requests under different registrations are not equivalent.
    private var currentRegistration: String {
        return mmContext.currentInstallation().pushRegistrationId ?? ""
    }
}
