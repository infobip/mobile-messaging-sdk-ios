// 
//  Example_static/NotificationServiceExtension/NotificationService.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import UserNotifications
import MobileMessagingNotificationExtension

class NotificationService: UNNotificationServiceExtension {

	var contentHandler: ((UNNotificationContent) -> Void)?
	var originalContent: UNNotificationContent?

	override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
		self.contentHandler = contentHandler
		self.originalContent = request.content

		if MobileMessagingNotificationServiceExtension.isCorrectPayload(request.content.userInfo as? [String: Any] ?? [:]) {
			MobileMessagingNotificationServiceExtension.didReceive(request, withContentHandler: contentHandler)
		} else {
			// handling by another push provider different than Infobip's
			contentHandler(request.content)
		}
	}

	override func serviceExtensionTimeWillExpire() {
		MobileMessagingNotificationServiceExtension.serviceExtensionTimeWillExpire()
		if let originalContent = originalContent {
			contentHandler?(originalContent)
		}
	}
}
