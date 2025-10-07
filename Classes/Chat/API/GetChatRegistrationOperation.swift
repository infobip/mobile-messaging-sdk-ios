// 
//  GetChatRegistrationOperation.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class GetChatRegistrationsOperation: MMOperation {
	let mmContext: MobileMessaging
	let finishBlock: ((NSError?, [String: String]?) -> Void)
	var operationResult = MMGetChatRegistrationsResult.Cancel

    init(mmContext: MobileMessaging, finishBlock: @escaping ((NSError?, [String: String]?) -> Void)) {
		self.mmContext = mmContext
		self.finishBlock = finishBlock
		super.init(isUserInitiated: false)
		self.addCondition(HealthyRegistrationCondition(mmContext: mmContext))
	}

	override func execute() {
		guard !isCancelled else {
			logDebug("cancelled...")
			finish()
			return
		}
		logDebug("Started...")

		performRequest()
	}

	private func performRequest() {
        mmContext.remoteApiProvider.getChatRegistrations(
            applicationCode: mmContext.applicationCode,
            pushRegistrationId: mmContext.currentInstallation().pushRegistrationId,
            queue: underlyingQueue) { (result) in
                self.operationResult = result
                self.finishWithError(result.error)
		}
	}

	override func finished(_ errors: [NSError]) {
        logDebug("finished with errors: \(errors)")
		finishBlock(errors.first, operationResult.value?.chatRegistrations)
	}
}
