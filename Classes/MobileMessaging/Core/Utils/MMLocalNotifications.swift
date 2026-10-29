// 
//  MMLocalNotifications.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UserNotifications

class LocalNotifications: NamedLogger {
	static var addNotificationRequest: (UNNotificationRequest, @escaping (Error?) -> Void) -> Void = { request, completion in
		UNUserNotificationCenter.current().add(request, withCompletionHandler: completion)
	}

	class func presentLocalNotification(with message: MM_MTMessage, isPresentedByExtension: (() -> Bool)? = nil) {
		MobileMessaging.messageHandlingDelegate?.willScheduleLocalNotification?(for: message)
		LocalNotifications.scheduleUserNotification(with: message, isPresentedByExtension: isPresentedByExtension, completion: nil)
	}

	class func scheduleUserNotification(with message: MM_MTMessage, isPresentedByExtension: (() -> Bool)? = nil, completion: (() -> Void)?) {
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
			guard let isPresentedByExtension = isPresentedByExtension else {
				add(req, completion: completion)
				return
			}
            
			DispatchQueue.global(qos: .default).async {
				guard !isPresentedByExtension() else {
					logDebug("skipping scheduled notification for \(message.messageId), notification service extension already handles it")
					completion?()
					return
				}
				add(req, completion: completion)
			}
		})
	}

	private class func add(_ request: UNNotificationRequest, completion: (() -> Void)?) {
		logDebug("scheduling notification for \(request.identifier)")
		addNotificationRequest(request) { error in
			if let error = error {
				logError("Error while scheduling local notification: \(error)")
			}
			completion?()
		}
	}
}
