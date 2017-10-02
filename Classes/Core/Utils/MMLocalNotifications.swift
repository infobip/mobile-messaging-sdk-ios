//
//  MMLocalNotifications.swift
//
//  Created by Andrey K. on 12/09/16.
//
//

import Foundation
import UserNotifications

struct LocalNotificationKeys {
	static let pushPayload = "com.mobile-messaging.ln.k.pushPayload"
}

class LocalNotifications {
	class func presentLocalNotification(with message: MTMessage, completion: (() -> Void)?) {
		guard !message.isSilent || (message.isGeoSignalingMessage) else {
			completion?()
			return
		}
		
		if #available(iOS 10.0, *) {
			LocalNotifications.scheduleUserNotification(with: message, completion: completion)
		} else {
			MMLogDebug("[Local Notification] presenting notification for \(message.messageId)")
			MobileMessaging.sharedInstance?.application.presentLocalNotificationNow(UILocalNotification.make(with: message))
			completion?()
		}
	}
	
	@available(iOS 10.0, *)
	class func scheduleUserNotification(with message: MTMessage, completion: (() -> Void)?) {
		guard let txt = message.text else {
			completion?()
			return
		}
		let content = UNMutableNotificationContent()
		if let categoryId = message.aps.category {
			content.categoryIdentifier = categoryId
		}
		if let title = message.title {
			content.title = title
		}
		content.body = txt
		content.userInfo = [LocalNotificationKeys.pushPayload: message.originalPayload]
		if let sound = message.sound {
			if sound == "default" {
				content.sound = UNNotificationSound.default()
			} else {
				content.sound = UNNotificationSound.init(named: sound)
			}
		}
		
		message.downloadImageAttachment(completion: { (url, error) in
			if let fileUrl = url {
				do {
					let att = try UNNotificationAttachment(identifier: fileUrl.absoluteString, url: fileUrl)
					content.attachments = [att]
				} catch let e {
					MMLogError("Error while building local notification attachment: \(e as? String)")
				}
			}
			let req = UNNotificationRequest(identifier: message.messageId, content: content, trigger: nil)
			MMLogDebug("[Local Notification] scheduling notification for \(message.messageId)")
			UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
			completion?()
		})
	}
}

extension UILocalNotification {
	class func make(with message: MTMessage) -> UILocalNotification {
		let localNotification = UILocalNotification()
		localNotification.userInfo = [LocalNotificationKeys.pushPayload: message.originalPayload]
		localNotification.alertBody = message.text
		localNotification.soundName = message.sound
		if #available(iOS 8.2, *) {
			localNotification.alertTitle = message.title
		}
		localNotification.category = message.aps.category
		return localNotification
	}
}
