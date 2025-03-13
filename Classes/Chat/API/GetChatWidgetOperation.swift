//
//  GetChatWidgetOperation.swift
//  MobileMessaging
//
//  Created by okoroleva on 24.04.2020.
//

import Foundation

class GetChatWidgetOperation: MMOperation {
	let mmContext: MobileMessaging
	let finishBlock: ((NSError?, ChatWidget?) -> Void)
	var operationResult = GetChatWidgetResult.Cancel

	init(mmContext: MobileMessaging, finishBlock: @escaping ((NSError?, ChatWidget?) -> Void)) {
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
        mmContext.remoteApiProvider.getChatWidget(
            applicationCode: mmContext.applicationCode,
            pushRegistrationId: mmContext.currentInstallation().pushRegistrationId,
            queue: underlyingQueue) { (result) in
                self.operationResult = result
                self.finishWithError(result.error)
		}
	}

	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		finishBlock(errors.first, operationResult.value?.widget)
	}
}
