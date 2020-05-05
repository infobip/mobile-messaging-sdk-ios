//
//  GetChatWidgetOperation.swift
//  MobileMessaging
//
//  Created by okoroleva on 24.04.2020.
//

import Foundation

class GetChatWidgetOperation: Operation {
	let mmContext: MobileMessaging
	let finishBlock: ((NSError?, ChatWidget?) -> Void)
	var operationResult = GetChatWidgetResult.Cancel

	init(mmContext: MobileMessaging, finishBlock: @escaping ((NSError?, ChatWidget?) -> Void)) {
		self.mmContext = mmContext
		self.finishBlock = finishBlock
	}

	override func execute() {
		guard !isCancelled else {
			MMLogDebug("[GetChatWidgetOperation] cancelled...")
			finish()
			return
		}
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogWarn("[GetChatWidgetOperation] Registration is not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.InvalidRegistration))
			return
		}
		MMLogDebug("[GetChatWidgetOperation] Started...")

		performRequest()
	}

	private func performRequest() {
		mmContext.remoteApiProvider.getChatWidget(applicationCode: mmContext.applicationCode, pushRegistrationId: mmContext.currentInstallation().pushRegistrationId) { (result) in
			self.operationResult = result
			self.finishWithError(result.error)
		}
	}

	override func finished(_ errors: [NSError]) {
		MMLogDebug("[GetChatWidgetOperation] finished with errors: \(errors)")
		finishBlock(errors.first, operationResult.value?.widget)
	}
}
