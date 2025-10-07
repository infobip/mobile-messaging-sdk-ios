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
		logDebug("starting...")
		DepersonalizeOperation.depersonalizeSubservices(userInitiated: userInitiated, mmContext: mmContext)
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
			DepersonalizeOperation.handleSuccessfulDepersonalize(mmContext: self.mmContext)
		case .Failure(let error):
			logError("request failed with error: \(error.orNil)")
			DepersonalizeOperation.handleFailedDepersonalize(mmContext: self.mmContext)
		case .Cancel:
			logWarn("request cancelled.")
		}
	}

	class func handleSuccessfulDepersonalize(mmContext: MobileMessaging) {
		switch mmContext.internalData().currentDepersonalizationStatus {
		case .pending:
			DepersonalizeOperation.logDebug("current depersonalize status: pending")

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

    class func depersonalizeSubservices(userInitiated: Bool, mmContext: MobileMessaging) {
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
		}
	}
	
	override func finished(_ errors: [NSError]) {
        logDebug("finished with errors: \(errors)")
        self.finishBlock?(self.mmContext.internalData().currentDepersonalizationStatus, errors.first)
	}
}
