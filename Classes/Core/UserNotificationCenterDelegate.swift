//
//  UserNotificationCenterDelegate.swift
//
//  Created by Andrey Kadochnikov on 14/09/2017.
//
//

import Foundation
import UserNotifications

extension MTMessage {
	@available(iOS 10.0, *)
	class func make(with notification: UNNotification) -> MTMessage? {
		return MTMessage(payload: notification.request.content.userInfo,
						 deliveryMethod: .undefined,
						 seenDate: nil,
						 deliveryReportDate: nil,
						 seenStatus: .NotSeen,
						 isDeliveryReportSent: false)
	}
}

@available(iOS 10.0, *)
extension UNNotificationPresentationOptions {
	static func make(with userNotificationType: UserNotificationType) -> UNNotificationPresentationOptions {
		var ret: UNNotificationPresentationOptions = []
		if userNotificationType.contains(options: .alert) {
			ret.insert(.alert)
		}
		if userNotificationType.contains(options: .badge) {
			ret.insert(.badge)
		}
		if userNotificationType.contains(options: .sound) {
			ret.insert(.sound)
		}
		return ret
	}
}

@available(iOS 10.0, *)
class UserNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
	static let sharedInstance = UserNotificationCenterDelegate()

	public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

		let mtMessage: MTMessage? = MTMessage.make(with: notification)

		MobileMessaging.messageHandlingDelegate?.willPresentInForeground?(message: mtMessage, notification: notification, withCompletionHandler: { (notificationType) in
			completionHandler(UNNotificationPresentationOptions.make(with: notificationType))
		}) ??
			completionHandler(presentationOptions(for: mtMessage))

		MobileMessaging.sharedInstance?.didReceiveRemoteNotification(notification.request.content.userInfo, completion: { _ in })
	}

	public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Swift.Void) {
		
		didReceive(
			notificationUserInfo: response.notification.request.content.userInfo,
			actionId: response.actionIdentifier,
			categoryId: response.notification.request.content.categoryIdentifier,
			userText: (response as? UNTextInputNotificationResponse)?.userText,
			withCompletionHandler: { completionHandler() }
		)
	}

	func presentationOptions(for message: MTMessage?) -> UNNotificationPresentationOptions {
		let ret: UNNotificationPresentationOptions

		if let msg = message, msg.inAppStyle == .Banner {
			ret = UNNotificationPresentationOptions.make(with:  MobileMessaging.sharedInstance?.userNotificationType ?? [])
		} else {
			ret = []
		}
		return ret
	}

	func didReceive(notificationUserInfo: [AnyHashable: Any], actionId: String?, categoryId: String?, userText: String?, withCompletionHandler completionHandler: @escaping () -> Swift.Void) {
		MMLogDebug("[Notification Center Delegate] received response")
		guard let service = NotificationsInteractionService.sharedInstance else
		{
			MMLogDebug("[Notification Center Delegate] stopped due to unintialized iteraction service")
			completionHandler()
			return
		}
		
		let responseInfo: [AnyHashable: Any]?
		if let userText = userText {
			responseInfo = [UIUserNotificationActionResponseTypedTextKey : userText]
		} else {
			responseInfo = nil
		}
		
		let message = MTMessage(
			payload: notificationUserInfo,
			deliveryMethod: .undefined,
			seenDate: nil,
			deliveryReportDate: nil,
			seenStatus: .NotSeen,
			isDeliveryReportSent: false)
		
		service.handleAction(
			identifier: actionId,
			categoryId: categoryId,
			message: message,
			notificationUserInfo: notificationUserInfo as? [String: Any],
			responseInfo: responseInfo,
			completionHandler: completionHandler
		)
	}
}
