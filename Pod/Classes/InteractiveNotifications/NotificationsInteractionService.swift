//
//  NotificationsInteractionService.swift
//
//  Created by Andrey Kadochnikov on 14/08/2017.
//
//

import Foundation
import UserNotifications

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
	public func withInteractiveNotificationCategories(_ categories: Set<NotificationCategory>) -> MobileMessaging {
		if !categories.isEmpty {
			NotificationsInteractionService.sharedInstance = NotificationsInteractionService(mmContext: self, categories: categories)
		}
		return self
	}
	
	/// This method handles interactive notifications actions and performs work that is defined for this action. The method should be called from AppDelegate's `application(_:handleActionWithIdentifier:for:withResponseInfo:completionHandler:)` callback.
	///
	/// - parameter identifier: The identifier for the interactive notification action.
	/// - parameter localNotification: The local notification object that was triggered.
    /// - parameter responseInfo: The data dictionary sent by the action. Potentially could contain text entered by the user in response to the text input action.
	/// - parameter completionHandler: A block that you must call when you are finished performing the action. It is originally passed to AppDelegate's `application(_:handleActionWithIdentifier:for:withResponseInfo:completionHandler:)` callback as a `completionHandler` parameter.
	public class func handleActionWithIdentifier(identifier: String?, localNotification: UILocalNotification, responseInfo: [AnyHashable: Any]?, completionHandler: @escaping () -> Void) {
		guard let info = localNotification.userInfo,
			let payload = info[LocalNotificationKeys.pushPayload] as? [String: Any] else
		{
			completionHandler()
			return
		}
		
        handleActionWithIdentifier(identifier: identifier, message: MTMessage(payload: payload), responseInfo: responseInfo, completionHandler: completionHandler)
	}
	
	/// This method handles interactive notifications actions and performs work that is defined for this action. The method should be called from AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)` callback.
	///
	/// - parameter identifier: The identifier for the interactive notification action.
    /// - parameter userInfo: A dictionary that contains information related to the remote notification. This dictionary originates from the provider as a JSON-defined dictionary, which iOS converts to an NSDictionary object before calling this method. The contents of the dictionary are the remote notification payload, which consists only of property-list objects plus NSNull
    /// - parameter responseInfo: The data dictionary sent by the action. Potentially could contain text entered by the user in response to the text input action.
	/// - parameter completionHandler: A block that you must call when you are finished performing the action. It is originally passed to AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)` callback as a `completionHandler` parameter.
	public class func handleActionWithIdentifier(identifier: String?, forRemoteNotification userInfo: [AnyHashable: Any], responseInfo: [AnyHashable: Any]?, completionHandler: @escaping () -> Void) {
		handleActionWithIdentifier(identifier: identifier, message: MTMessage(payload: userInfo), responseInfo: responseInfo, completionHandler: completionHandler)
	}
	
    /// This method handles interactive notifications actions and performs work that is defined for this action.
    ///
    /// - parameter identifier: The identifier for the interactive notification action.
    /// - parameter message: The `MTMessage` object the action associated with.
    /// - parameter responseInfo: The data dictionary sent by the action. Potentially could contain text entered by the user in response to the text input action.
    /// - parameter completionHandler: A block that you must call when you are finished performing the action.
	public class func handleActionWithIdentifier(identifier: String?, message: MTMessage?, responseInfo: [AnyHashable: Any]?, completionHandler: @escaping () -> Void) {
		guard let service = NotificationsInteractionService.sharedInstance else
		{
			completionHandler()
			return
		}
		service.handleActionWithIdentifier(identifier: identifier, message: message, responseInfo: responseInfo, completionHandler: completionHandler)
	}
	
	/// Returns `NotificationCategory` object for provided category Id. Category Id can be obtained from `MTMessage` object with `MTMessage.category` method.
	/// - parameter identifier: The identifier associated with the category of interactive notification
	public class func category(withId identifier: String) -> NotificationCategory? {
		return NotificationsInteractionService.sharedInstance?.allNotificationCategories?.first(where: {$0.identifier == identifier})
	}
}

class NotificationsInteractionService: MobileMessagingService {
	struct Constants {
		static let actionHandlingTimeout = 20
	}
	
	let mmContext: MobileMessaging
	
	let customNotificationCategories: Set<NotificationCategory>?

	var allNotificationCategories: Set<NotificationCategory>? {
		return customNotificationCategories + NotificationCategories.predefinedCategories
	}
	
	static var sharedInstance: NotificationsInteractionService?
	
	init(mmContext: MobileMessaging, categories: Set<NotificationCategory>?) {
		self.customNotificationCategories = categories
		self.mmContext = mmContext
		registerSelfAsSubservice(of: mmContext)
	}
	
    func handleActionWithIdentifier(identifier: String?, message: MTMessage?, responseInfo: [AnyHashable: Any]?, completionHandler: @escaping () -> Void) {
		guard isRunning,
			let identifier = identifier,
			let message = message else
		{
			completionHandler()
			return
		}
		
		let handleAction: (NotificationAction?) -> Void = { action in
			message.appliedAction = action
			self.mmContext.messageHandler.handleMTMessage(message, notificationTapped: action == nil, completion: { _ in
				completionHandler()
			})
		}	
		
		if #available(iOS 10.0, *), identifier == UNNotificationDismissActionIdentifier
		{
			handleAction(NotificationAction.dismissAction)
		}
		else if #available(iOS 10.0, *), identifier == UNNotificationDefaultActionIdentifier
		{
			handleAction(nil)
		}
		else if	let categoryId = message.aps.category,
					let category = allNotificationCategories?.first(where: { $0.identifier == categoryId }),
					let action = category.actions.first(where: { $0.identifier == identifier })
		{
			if	#available(iOS 9.0, *),
				let responseInfo = responseInfo,
				let action = action as? TextInputNotificationAction,
				let typedText = responseInfo[UIUserNotificationActionResponseTypedTextKey] as? String
			{
				action.typedText = typedText
				handleAction(action)
			} else {
				handleAction(action)
			}
		}
		else {
			completionHandler()
		}
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
            self.mmContext.sendMessagesSDKInitiated([MOMessage(destination: nil, text: "\(category) \(appliedAction.identifier)", customPayload: nil, composedDate: MobileMessaging.date.now,
                                                               bulkId: message.internalData?[InternalDataKeys.bulkId] as? String, initialMessageId: message.messageId)]) { msgs, error in
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
