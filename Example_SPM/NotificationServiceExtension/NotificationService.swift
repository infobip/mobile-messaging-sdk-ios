//
//  NotificationService.swift
//  NotificationServiceExtension
//

import UserNotifications
import MobileMessaging
import MobileMessagingLogging

class NotificationService: UNNotificationServiceExtension {

	var contentHandler: ((UNNotificationContent) -> Void)?
	var originalContent: UNNotificationContent?
	
	override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
		self.contentHandler = contentHandler
		self.originalContent = request.content
		MobileMessagingNotificationServiceExtension.startWithApplicationCode("<# your application code #>")
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
