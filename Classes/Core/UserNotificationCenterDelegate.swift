//
//  UserNotificationCenterDelegate.swift
//
//  Created by Andrey Kadochnikov on 14/09/2017.
//
//

import Foundation
import UserNotifications

@available(iOS 10.0, *)
class UserNotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
	static let sharedInstance = UserNotificationCenterDelegate()
	
	public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Swift.Void) {
        
        handle(notificationUserInfo: response.notification.request.content.userInfo, actionId: response.actionIdentifier, userText: (response as? UNTextInputNotificationResponse)?.userText, withCompletionHandler: completionHandler)
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
