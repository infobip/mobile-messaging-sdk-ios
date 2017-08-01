//
//  MMNotificatioActionHandler.swift
//
//  Created by okoroleva on 27.07.17.
//
//

@objc public protocol NotificationActionHandling {
	
	/// This method will be triggered during the notification action handling.
	/// - parameter action: `MMNotificationAction` object defining the action which was triggered.
	/// - parameter message: `MTMessage` message, for which action button was displayed, you can use `message.categoryId` in order to check the categoryId for action.
	/// - parameter completionHandler: The block to execute when specified action performing finished. The block is originally passed to AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:completionHandler:)` callback as a `completionHandler` parameter.
	func handle(action: MMNotificationAction, forMessage message: MTMessage, withCompletionHandler completionHandler: @escaping () -> Void)
}
