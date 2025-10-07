// 
//  Example/NotificationServiceExtension/NotificationService.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import UserNotifications
import MobileMessaging

class NotificationService: UNNotificationServiceExtension {

	var contentHandler: ((UNNotificationContent) -> Void)?
	var originalContent: UNNotificationContent?
	
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.originalContent = request.content
        if MM_MTMessage.isCorrectPayload(request.content.userInfo) {
            MobileMessaging.logger = MMLumberjackLogger(logOutput: MMLogOutput.Console, logLevel: MMLogLevel.All)
            MobileMessagingNotificationServiceExtension.didReceive(request, withContentHandler: contentHandler)
        } else {
            //handling by another push provider
        }
    }
	
	override func serviceExtensionTimeWillExpire() {
		MobileMessagingNotificationServiceExtension.serviceExtensionTimeWillExpire()
		if let originalContent = originalContent {
			contentHandler?(originalContent)
		}
	}
}
