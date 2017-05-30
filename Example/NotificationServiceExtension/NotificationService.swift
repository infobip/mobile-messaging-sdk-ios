//
//  NotificationService.swift
//  NotificationServiceExtension
//

import UserNotifications
import MobileMessaging

class NotificationService: UNNotificationServiceExtension {

	var contentHandler: ((UNNotificationContent) -> Void)?
	var content: UNMutableNotificationContent?
	
	override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
		self.contentHandler = contentHandler
		self.content = (request.content.mutableCopy() as? UNMutableNotificationContent)
		MobileMessagingNotificationServiceExtension.startWithApplicationCode("<# your application code #>" , appGroupId: "group.com.mobile-messaging.notification-service-extension")
		MobileMessagingNotificationServiceExtension.didReceive(request, withContentHandler: contentHandler)
	}
	
	override func serviceExtensionTimeWillExpire() {
		MobileMessagingNotificationServiceExtension.serviceExtensionTimeWillExpire()
		if let contentHandler = contentHandler, let bestAttemptContent =  content {
			contentHandler(bestAttemptContent)
		}
	}
}

