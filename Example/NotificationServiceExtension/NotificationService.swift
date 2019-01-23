//
//  NotificationService.swift
//  NotificationServiceExtension
//

import UserNotifications
import MobileMessaging

class NotificationService: UNNotificationServiceExtension {

	var contentHandler: ((UNNotificationContent) -> Void)?
	var originalContent: UNNotificationContent?
	
	override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
		self.contentHandler = contentHandler
		self.originalContent = request.content
		MobileMessagingNotificationServiceExtension.startWithApplicationCode("3c59f6e341a6896fc05b8cd7e3f3fdf8-031a75db-fd8f-46b0-9f2b-a2e915d7b952_")
		MobileMessaging.logger = MMLumberjackLogger(logOutput: MMLogOutput.Console, logLevel: MMLogLevel.All)
		MobileMessagingNotificationServiceExtension.didReceive(request, withContentHandler: contentHandler)
	}
	
	override func serviceExtensionTimeWillExpire() {
		MobileMessagingNotificationServiceExtension.serviceExtensionTimeWillExpire()
		if let originalContent = originalContent {
			contentHandler?(originalContent)
		}
	}
}
