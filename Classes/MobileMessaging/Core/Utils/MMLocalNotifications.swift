//
//  MMLocalNotifications.swift
//
//  Created by Andrey K. on 12/09/16.
//
//

import Foundation
import UserNotifications

class LocalNotifications: NamedLogger {
	class func presentLocalNotification(with message: MM_MTMessage) {
		MobileMessaging.messageHandlingDelegate?.willScheduleLocalNotification?(for: message)
		LocalNotifications.scheduleUserNotification(with: message)
	}
	
	class func scheduleUserNotification(with message: MM_MTMessage) {
		guard let txt = message.text else {
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
		content.userInfo = message.originalPayload
		if let sound = message.sound {
			if sound == "default" {
				content.sound = UNNotificationSound.default
			} else {
				content.sound = UNNotificationSound.init(named: UNNotificationSoundName(rawValue: sound))
			}
		}
		
		message.downloadImageAttachment(completion: { (downloadedFileUrl, error) in
			if let downloadedFileUrl = downloadedFileUrl {
				do {
					let att = try UNNotificationAttachment(identifier: downloadedFileUrl.absoluteString, url: downloadedFileUrl)
					content.attachments = [att]
				} catch let e {
					logError("Error while building local notification attachment: \(String(describing: e))")
				}
			}
			let req = UNNotificationRequest(identifier: message.messageId, content: content, trigger: nil)
			logDebug("scheduling notification for \(message.messageId)")
			UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
		})
	}
}
