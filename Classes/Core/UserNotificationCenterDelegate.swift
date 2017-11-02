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
		guard let service = NotificationsInteractionService.sharedInstance else
		{
			completionHandler()
			return
		}
        
        let responseInfo: [AnyHashable: Any]?
        if let userText = (response as? UNTextInputNotificationResponse)?.userText {
            responseInfo = [UIUserNotificationActionResponseTypedTextKey : userText]
        } else {
            responseInfo = nil
        }
        
		service.handleActionWithIdentifier(identifier: response.actionIdentifier, message: MTMessage(payload: response.notification.request.content.userInfo), responseInfo: responseInfo, completionHandler: completionHandler)
	}
}
