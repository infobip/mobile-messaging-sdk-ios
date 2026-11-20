// 
//  DepersonalizeOperation.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import CoreData

class DepersonalizeOperation: MMOperation {
	let mmContext: MobileMessaging
	let finishBlock: ((MMSuccessPending, NSError?) -> Void)?
	let pushRegistrationId: String?
	let applicationCode: String
	/// Taken when the operation runs: an identical logout queued before this one has finished by then.
	private var debounceTicket: MMDebouncingGuard.Ticket?
	private var didSucceed = false
	
    init(userInitiated: Bool, mmContext: MobileMessaging, finishBlock: ((MMSuccessPending, NSError?) -> Void)? = nil) {
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		self.pushRegistrationId = mmContext.resolveInstallation().pushRegistrationId
		self.applicationCode = mmContext.applicationCode
        super.init(isUserInitiated: userInitiated)
	}
	
	override func execute() {
        guard !isCancelled else {
            logDebug("cancelled...")
            finish()
            return
        }
		// Same type and key as depersonalizing another installation (like Android's depersonalizeById): an identical
		// logout that succeeded within the window makes this one a duplicate. Checked before the cleanup, so a
		// duplicate does not clean up the subservices again.
		if let pushRegistrationId = pushRegistrationId {
			let ticket = mmContext.debouncingGuard.admit(.depersonalizeInstallation, data: ["pushRegId": pushRegistrationId, "registration": pushRegistrationId])
			// a pending logout (an earlier one failed) is always sent, whatever the guard remembers
			guard ticket != nil || mmContext.internalData().currentDepersonalizationStatus == .pending else {
				logDebug("identical logout succeeded meanwhile, not sent")
				finish()
				return
			}
			debounceTicket = ticket
		}
		logDebug("starting...")
		// keeps its own entry: the cleanup belongs to this very logout
		DepersonalizeOperation.depersonalizeSubservices(userInitiated: userInitiated, mmContext: mmContext, keepingDebounceOf: .depersonalizeInstallation)
		self.sendRequest()
	}
	
	private func sendRequest() {
		guard !isCancelled else {
			logDebug("cancelled...")
			finish()
			return
		}
		if let pushRegistrationId = pushRegistrationId {
			logDebug("performing request...")
            mmContext.remoteApiProvider.depersonalize(applicationCode: self.applicationCode, pushRegistrationId: pushRegistrationId, pushRegistrationIdToDepersonalize: pushRegistrationId, queue: self.underlyingQueue, completion: { result in
				self.handleResult(result)
				self.finishWithError(result.error)
			})
		} else {
			finishWithError(NSError(type: .NoRegistration))
		}
	}
	
	private func handleResult(_ result: DepersonalizeResult) {
        assert(!Thread.isMainThread)
		switch result {
		case .Success:
			logDebug("request secceeded")
			didSucceed = true
			DepersonalizeOperation.handleSuccessfulDepersonalize(mmContext: self.mmContext, keepingDebounceOf: .depersonalizeInstallation)
		case .Failure(let error):
			logError("request failed with error: \(error.orNil)")
			DepersonalizeOperation.handleFailedDepersonalize(mmContext: self.mmContext)
		case .Cancel:
			logWarn("request cancelled.")
		}
	}

	/// - parameter kept: see `depersonalizeSubservices`.
	class func handleSuccessfulDepersonalize(mmContext: MobileMessaging, keepingDebounceOf kept: MMDebouncingGuard.OperationType? = nil) {
		switch mmContext.internalData().currentDepersonalizationStatus {
		case .pending:
			DepersonalizeOperation.logDebug("current depersonalize status: pending")
			// a logout retried while pending: its subservice cleanup (and invalidation) was skipped, so calls made
			// while it was pending (e.g. a personalize) are only now undone on the server
			mmContext.debouncingGuard.invalidate(after: .logout, except: kept)

			let id = mmContext.internalData()
			id.currentDepersonalizationStatus = .success
			id.archiveCurrent()

			mmContext.apnsRegistrationManager.registerForRemoteNotifications(userInitiated: true)
            
		case .success, .undefined:
			DepersonalizeOperation.logDebug("current depersonalize status: undefined/succesful")
		}
		UserEventsManager.postDepersonalizedEvent()
	}

	class func handleFailedDepersonalize(mmContext: MobileMessaging) {

		let id = mmContext.internalData()
		id.depersonalizeFailCounter = id.depersonalizeFailCounter + 1

		switch id.currentDepersonalizationStatus {
		case .pending:
			logDebug("current depersonalize status: pending, depersonalizeFailCounter: \(id.depersonalizeFailCounter)/\(DepersonalizationConsts.failuresNumberLimit)")
			if id.depersonalizeFailCounter >= DepersonalizationConsts.failuresNumberLimit {

				id.currentDepersonalizationStatus = .undefined

				mmContext.apnsRegistrationManager.registerForRemoteNotifications(userInitiated: true)
			}
            id.archiveCurrent()

		case .success, .undefined:
			logDebug("current depersonalize status: undefined/successful")

			id.currentDepersonalizationStatus = .pending
			id.archiveCurrent()

			mmContext.apnsRegistrationManager.unregister(userInitiated: false)
		}
	}

    /// - parameter kept: debounce entry of the caller, kept although the user is reset: a forced personalize
    ///   depersonalizes as part of its own call. A plain logout keeps none.
    class func depersonalizeSubservices(userInitiated: Bool, mmContext: MobileMessaging, keepingDebounceOf kept: MMDebouncingGuard.OperationType? = nil) {
		switch mmContext.internalData().currentDepersonalizationStatus {
		case .pending: break
		case .success, .undefined:
			let loopGroup = DispatchGroup()
			logDebug("depersonalizing subservices...")
			mmContext.subservices.values.forEach { subservice in
				loopGroup.enter()
                subservice.depersonalizeService(mmContext, userInitiated: userInitiated, completion: {
					loopGroup.leave()
				})
			}

			_ = loopGroup.wait(timeout: DispatchTime.now() + .seconds(10))
			mmContext.debouncingGuard.invalidate(after: .logout, except: kept)
		}
	}
	
	override func finished(_ errors: [NSError]) {
        logDebug("finished with errors: \(errors)")
        debounceTicket.map { mmContext.debouncingGuard.finish($0, succeeded: didSucceed) }
        self.finishBlock?(self.mmContext.internalData().currentDepersonalizationStatus, errors.first)
	}
}
