//
//  NotificationsInteractionService.swift
//
//  Created by Andrey Kadochnikov on 14/08/2017.
//
//

import Foundation

@objc public protocol NotificationActionHandling {
	/// This method will be triggered during the notification action handling.
	/// - parameter action: `NotificationAction` object defining the action which was triggered.
	/// - parameter message: `MTMessage` message, for which action button was displayed, you can use `message.categoryId` in order to check the categoryId for action.
	/// - parameter completionHandler: The block to execute when specified action performing is finished. You must call this block once the work is completed. The block is originally passed to AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:completionHandler:)` callback as a `completionHandler` parameter.
	func handle(action: NotificationAction, forMessage message: MTMessage, withCompletionHandler completionHandler: @escaping () -> Void)
}

extension MobileMessaging {
	/// The `notificationActionHandler` object defines the custom behaviour that is triggered while handling the interactive notifications action.
	///
	/// Implement your own notification action hander class by implementing the `NotificationActionHandling` protocol.
	public static var notificationActionHandler: NotificationActionHandling?
	
	/// Fabric method for Mobile Messaging session.
	///
	/// - parameter categories: Set of categories to define which buttons to display and their behavour.
	/// - remark: Mobile Messaging SDK reserves category Ids and action Ids with "mm_" prefix. Custom actions and categories with this prefix will be discarded.
	public func withInteractiveNotificationCategories(_ categories: Set<MMNotificationCategory>) -> MobileMessaging {
		if !categories.isEmpty {
			NotificationsInteractionService.sharedInstance = NotificationsInteractionService(mmContext: self, categories: categories)
		}
		return self
	}
	
	/// This method handles interactive notifications actions and performs work that is defined for this action. The method should be called from AppDelegate's `application(_:handleActionWithIdentifier:localNotification:completionHandler:)` callback.
	///
	/// - parameter identifier: The identifier associated with the action of interactive notification.
	/// - parameter localNotification: `UILocalNotification` object, which specifies notification that was scheduled.
	/// - parameter completionHandler: The block to execute when specified action performing finished. The block is originally passed to AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:completionHandler:)` callback as a `completionHandler` parameter.
	public class func handleActionWithIdentifier(identifier: String?, localNotification: UILocalNotification, responseInfo: [NSObject: AnyObject]?, completionHandler: @escaping () -> Void) {
		guard let info = localNotification.userInfo,
			let payload = info[LocalNotificationKeys.pushPayload] as? [String: Any],
			let date = info[LocalNotificationKeys.createdDate] as? Date,
			let service = NotificationsInteractionService.sharedInstance else
		{
			completionHandler()
			return
		}
		
		service.handleActionWithIdentifier(identifier: identifier, message: MTMessage(payload: payload, createdDate: date), completionHandler: completionHandler)
	}
	
	/// This method handles interactive notifications actions and performs work that is defined for this action. The method should be called from AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:completionHandler:)` callback.
	///
	/// - parameter identifier: The identifier associated with the action of interactive notification.
	/// - parameter userInfo: A dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	/// - parameter completionHandler: The block to execute when specified action performing finished. The block is originally passed to AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:completionHandler:)` callback as a `completionHandler` parameter.
	public class func handleActionWithIdentifier(identifier: String?, forRemoteNotification userInfo: [AnyHashable: Any], responseInfo: [NSObject: AnyObject]?, completionHandler: @escaping () -> Void) {
		guard let service = NotificationsInteractionService.sharedInstance else
		{
			completionHandler()
			return
		}
		
		service.handleActionWithIdentifier(identifier: identifier, message: MTMessage(payload: userInfo, createdDate: Date()), completionHandler: completionHandler)
	}
}

class NotificationsInteractionService: MobileMessagingService {
	struct Constants {
		static let actionHandlingTimeout = 20
	}
	
	let mmContext: MobileMessaging
	
	let customNotificationCategories: Set<MMNotificationCategory>?

	var allNotificationCategories: Set<MMNotificationCategory>? {
		return customNotificationCategories + MMNotificationCategories.predefinedCategories
	}
	
	var userNotificationCategories: Set<UIUserNotificationCategory>? {
		return allNotificationCategories?.uiUserNotificationCategoriesSet
	}
	
	static var sharedInstance: NotificationsInteractionService?
	
	init(mmContext: MobileMessaging, categories: Set<MMNotificationCategory>?) {
		self.customNotificationCategories = categories
		self.mmContext = mmContext
		registerSelfAsSubservice(of: mmContext)
	}
	
	func handleActionWithIdentifier(identifier: String?, message: MTMessage?, completionHandler: @escaping () -> Void) {
		guard isRunning,
			let identifier = identifier,
			let message = message,
			let categoryId = message.aps.category,
			let category = allNotificationCategories?.first(where: { $0.identifier == categoryId }),
			let action = category.actions.first(where: { $0.identifier == identifier }) else
		{
			completionHandler()
			return
		}
		
		message.appliedAction = action
		
		mmContext.messageHandler.handleMTMessage(message, notificationTapped: false, completion: { _ in
			completionHandler()
		})
	}
	
	//MARK: - Protocol requirements (MobileMessagingService)
	var isRunning: Bool = false
}

//MARK: - Protocol implementation (MobileMessagingService)
extension NotificationsInteractionService {
	var uniqueIdentifier: String {
		return "com.mobile-messaging.subservice.NotificationsInteractionService"
	}

	func mobileMessagingDidStop(_ mmContext: MobileMessaging) {
		stop()
		NotificationsInteractionService.sharedInstance = nil
	}
	
	func mobileMessagingDidStart(_ mmContext: MobileMessaging) {
		guard let cs = allNotificationCategories, !cs.isEmpty else {
			return
		}
		start(nil)
	}
	
	func handleAnyMessage(_ message: MTMessage, completion: ((MessageHandlingResult) -> Void)?) {
		guard isRunning, let category = message.category, let appliedAction = message.appliedAction else {
			completion?(.noData)
			return
		}
		
		let dispatchGroup = DispatchGroup()
		
		dispatchGroup.enter()
		mmContext.setSeen([message.messageId]) { _ in
			dispatchGroup.leave()
		}
		
		if appliedAction.options.contains(.moRequired) {
			dispatchGroup.enter()
			self.mmContext.sendMessagesSDKInitiated([MOMessage(destination: nil, text: "\(category) \(appliedAction.identifier)", customPayload: nil)]) { msgs, error in
				dispatchGroup.leave()
			}
		}
		
		if let notificationActionHanler = MobileMessaging.notificationActionHandler {
			dispatchGroup.enter()
			DispatchQueue.global(qos: .default).async {
				notificationActionHanler.handle(action: appliedAction, forMessage: message, withCompletionHandler: {
					dispatchGroup.leave()
				})
			}
		}
		
		_ = dispatchGroup.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(NotificationsInteractionService.Constants.actionHandlingTimeout))
		completion?(.noData)
	}
	
	func syncWithServer(_ completion: ((NSError?) -> Void)?) {
		self.mmContext.retryMoMessageSending() { (_, error) in
			completion?(error)
		}
	}
	
	func stop(_ completion: ((Bool) -> Void)? = nil) {
		isRunning = false
	}
	
	func start(_ completion: ((Bool) -> Void)? = nil) {
		isRunning = true
	}
}
