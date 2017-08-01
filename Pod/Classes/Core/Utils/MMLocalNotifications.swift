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
	static let createdDate = "com.mobile-messaging.ln.k.createdDate"
}

extension UILocalNotification {
	class func mm_presentLocalNotification(with message: MTMessage, completion: (() -> Void)?) {
		guard !message.isSilent || (message.isGeoSignalingMessage) else {
			completion?()
			return
		}

		if #available(iOS 10.0, *) {
			mm_scheduleUserNotification(with: message, completion: completion)
		} else {
			UIApplication.shared.presentLocalNotificationNow(mm_localNotification(with: message))
			completion?()
		}
	}

	class func mm_localNotification(with message: MTMessage) -> UILocalNotification {
		let localNotification = UILocalNotification()
		localNotification.userInfo = [LocalNotificationKeys.pushPayload: message.originalPayload,
									  LocalNotificationKeys.createdDate: message.createdDate]
		localNotification.alertBody = message.text
		localNotification.soundName = message.sound
		localNotification.category = message.aps.category
		return localNotification
	}
}

@available(iOS 10.0, *)
func mm_scheduleUserNotification(with message: MTMessage, completion: (() -> Void)?) {
	guard let txt = message.text else {
		completion?()
		return
	}
	let content = UNMutableNotificationContent()
	if let categoryId = message.aps.category {
		content.categoryIdentifier = categoryId
	}
	content.title = ""
	content.body = txt
	content.userInfo = [LocalNotificationKeys.pushPayload: message.originalPayload, LocalNotificationKeys.createdDate: message.createdDate]
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
		UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
		completion?()
	})
}
