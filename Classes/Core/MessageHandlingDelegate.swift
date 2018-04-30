//
//  MMDefaultMessageHandling.swift
//
//  Created by Andrey K. on 15/09/16.
//
//

import Foundation

@objc public protocol MessageHandlingDelegate {
	/// Called when a new message is received.
    /// - parameter message: the new message received
	@objc optional func didReceiveNewMessage(message: MTMessage)
    
    /// Called when a notification is delivered to a foreground app.
    /// If your app is in the foreground when a notification arrives, the MobileMessaging SDK calls this method to deliver the notification directly to your app. If you implement this method, you can take whatever actions are necessary to process the notification and update your app. When you finish, execute the completionHandler block and specify how you want the system to alert the user, if at all.
    @available(iOS 10.0, *)
    @objc optional func willPresentInForeground(message: MTMessage, withCompletionHandler completionHandler: @escaping (UserNotificationType) -> Void)
    
    /// Called when a notification is delivered to a foreground app.
    @available(iOS, deprecated: 10.0, message: "Use willPresentInForeground(message:withCompletionHandler:)")
    @objc optional func didReceiveNewMessageInForeground(message: MTMessage)

    /// Called when a local notification scheduled for a message. Apart from push messages that are pushed to the device by APNs and displayed by iOS automatically, MobileMessaging SDK delivers messages by pulling them from the server and generating them locally. These messages are displayed via Local Notifications.
    @objc optional func willScheduleLocalNotification(for message: MTMessage)
    
    /// Called when a notification action is performed by the user.
    /// - parameter action: `NotificationAction` object defining the action which was triggered.
    /// - parameter message: `MTMessage` message, for which action button was displayed, you can use `message.categoryId` in order to check the categoryId for action.
	/// - parameter notificationUserInfo: a dictionary representing original local/remote notification's userInfo
    /// - parameter completion: The block to execute when specified action performing is finished. **You must call this block either immediately or after your handling is completed.** The block is originally passed to AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:completionHandler:)` callback as a `completionHandler` parameter.
	@objc func didPerform(action: NotificationAction, forMessage message: MTMessage?, notificationUserInfo: [String: Any]?, completion: @escaping () -> Void)
}
