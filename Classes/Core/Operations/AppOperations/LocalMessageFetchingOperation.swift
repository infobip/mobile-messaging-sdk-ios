//
//  LocalMessageFetchingOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 20/09/2017.
//

import Foundation
import UserNotifications

class LocalMessageFetchingOperation : MMOperation {
	
	let notificationExtensionStorage: AppGroupMessageStorage?
	let finishBlock: ([MM_MTMessage]) -> Void
	let userNotificationCenterStorage: UserNotificationCenterStorage
	
	var result = Set<MM_MTMessage>()
	
	init(userNotificationCenterStorage: UserNotificationCenterStorage, notificationExtensionStorage: AppGroupMessageStorage?, finishBlock: @escaping ([MM_MTMessage]) -> Void) {
		self.notificationExtensionStorage = notificationExtensionStorage
		self.finishBlock = finishBlock
		self.userNotificationCenterStorage = userNotificationCenterStorage
		super.init(isUserInitiated: false)
	}
	
	override func execute() {
		self.retrieveMessagesFromNotificationServiceExtension(completion: { messages in
			self.logDebug("Retrieved \(messages.count) messages from notification extension storage.")
			self.result.formUnion(messages)
			
			self.retrieveMessagesFromUserNotificationCenter(completion: { messages in
				self.logDebug("Retrieved \(messages.count) messages from notification center.")
				self.result.formUnion(messages)
				self.finish()
			})
		})
	}
	
	private func retrieveMessagesFromNotificationServiceExtension(completion: @escaping ([MM_MTMessage]) -> Void) {
		if let messages = notificationExtensionStorage?.retrieveMessages() {
			if !messages.isEmpty {
				notificationExtensionStorage?.cleanupMessages()
			}
			completion(messages)
		} else {
			completion([])
		}
	}
	
	private func retrieveMessagesFromUserNotificationCenter(completion: @escaping ([MM_MTMessage]) -> Void) {
		userNotificationCenterStorage.getDeliveredMessages(completionHandler: completion)
	}
	
	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		let messages = Array(result)
		finishBlock(messages)
	}
}
