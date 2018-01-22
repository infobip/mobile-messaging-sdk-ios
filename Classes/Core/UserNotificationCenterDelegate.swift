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
        return MTMessage(payload: notification.request.content.userInfo)
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
        guard let mm = MobileMessaging.sharedInstance, let message = MTMessage.make(with: notification) else {
            completionHandler([])
            return
        }
        
        MobileMessaging.sharedInstance?.messageHandlingDelegate?.willPresentInForeground?(message: message) { (notificationType) in
            completionHandler(UNNotificationPresentationOptions.make(with: notificationType))
        } ?? completionHandler([])
        
        mm.didReceiveRemoteNotification(notification.request.content.userInfo, completion: { _ in })
    }
    
	public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Swift.Void) {
        handle(notificationUserInfo: response.notification.request.content.userInfo, actionId: response.actionIdentifier, userText: (response as? UNTextInputNotificationResponse)?.userText, withCompletionHandler: {
            completionHandler()
        })
	}
    
    func handle(notificationUserInfo: [AnyHashable: Any], actionId: String, userText: String?, withCompletionHandler completionHandler: @escaping () -> Swift.Void) {
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
        
        service.handleActionWithIdentifier(identifier: actionId, message: MTMessage(payload: notificationUserInfo), responseInfo: responseInfo, completionHandler: completionHandler)
    }
}
