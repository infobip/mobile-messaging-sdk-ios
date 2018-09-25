//
//  NotificationsInteractionService.swift
//
//  Created by Andrey Kadochnikov on 14/08/2017.
//
//

import Foundation
import UserNotifications

extension MobileMessaging {
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
	@available(iOS, deprecated: 10.0)
	public class func handleActionWithIdentifier(identifier: String?, localNotification: UILocalNotification, responseInfo: [AnyHashable: Any]?, completionHandler: @escaping () -> Void) {
		
		let message: MTMessage? = {
			if let payload = localNotification.userInfo {
				return MTMessage(payload: payload,
								 deliveryMethod: .undefined,
								 seenDate: nil,
								 deliveryReportDate: nil,
								 seenStatus: .NotSeen,
								 isDeliveryReportSent: false)
			} else {
				return nil
			}
		}()
		
		handleAction(
			identifier: identifier,
			category: localNotification.category,
			message: message,
			notificationUserInfo: localNotification.userInfo as? [String : Any],
			responseInfo: responseInfo,
			completionHandler: completionHandler
		)
	}
	
	/// This method handles interactive notifications actions and performs work that is defined for this action. The method should be called from AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)` callback.
	///
	/// - parameter identifier: The identifier for the interactive notification action.
	/// - parameter userInfo: A dictionary that contains information related to the remote notification. This dictionary originates from the provider as a JSON-defined dictionary, which iOS converts to an NSDictionary object before calling this method. The contents of the dictionary are the remote notification payload, which consists only of property-list objects plus NSNull
	/// - parameter responseInfo: The data dictionary sent by the action. Potentially could contain text entered by the user in response to the text input action.
	/// - parameter completionHandler: A block that you must call when you are finished performing the action. It is originally passed to AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)` callback as a `completionHandler` parameter.
	public class func handleActionWithIdentifier(identifier: String?, forRemoteNotification userInfo: [AnyHashable: Any], responseInfo: [AnyHashable: Any]?, completionHandler: @escaping () -> Void) {
		let message = MTMessage(payload: userInfo,
								deliveryMethod: .undefined,
								seenDate: nil,
								deliveryReportDate: nil,
								seenStatus: .NotSeen,
								isDeliveryReportSent: false)
		
		handleAction(
			identifier: identifier,
			category: message?.category,
			message: message,
			notificationUserInfo: userInfo as? [String: Any],
			responseInfo: responseInfo,
			completionHandler: completionHandler
		)
	}
	
	/// This method handles interactive notifications actions and performs work that is defined for this action.
	///
	/// - parameter identifier: The identifier for the interactive notification action.
	/// - parameter message: The `MTMessage` object the action associated with.
	/// - parameter responseInfo: The data dictionary sent by the action. Potentially could contain text entered by the user in response to the text input action.
	/// - parameter completionHandler: A block that you must call when you are finished performing the action.
	class func handleAction(identifier: String?, category: String?, message: MTMessage?, notificationUserInfo: [String: Any]?, responseInfo: [AnyHashable: Any]?, completionHandler: @escaping () -> Void) {
		guard let service = NotificationsInteractionService.sharedInstance else
		{
			MMLogWarn("NotificationsInteractionService is not initialized, canceling action handling")
			completionHandler()
			return
		}
		
		service.handleAction(
			identifier: identifier,
			categoryId: category,
			message: message,
			notificationUserInfo: notificationUserInfo,
			responseInfo: responseInfo,
			completionHandler: completionHandler
		)
	}
	
	/// Returns `NotificationCategory` object for provided category Id. Category Id can be obtained from `MTMessage` object with `MTMessage.category` method.
	/// - parameter identifier: The identifier associated with the category of interactive notification
	public class func category(withId identifier: String) -> NotificationCategory? {
		return NotificationsInteractionService.sharedInstance?.allNotificationCategories?.first(where: {$0.identifier == identifier})
	}
}

class NotificationsInteractionService: MobileMessagingService {
	func pushRegistrationStatusDidChange(_ mmContext: MobileMessaging) { }

	func logoutStatusDidChange(_ mmContext: MobileMessaging) { }

	func logout(_ mmContext: MobileMessaging, completion: @escaping ((NSError?) -> Void)) {
		// do nothing
		completion(nil)
	}
	
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
	
	func handleLocalNotificationTap(localNotification: UILocalNotification, completion: (() -> Void)? = nil) {
		DispatchQueue.global(qos: .default).async {
			if let messagePayload = localNotification.userInfo,
				let message = MTMessage(payload: messagePayload,
										deliveryMethod: .undefined,
										seenDate: nil,
										deliveryReportDate: nil,
										seenStatus: .NotSeen,
										isDeliveryReportSent: false)
			{
				message.appliedAction = NotificationAction.defaultAction
				self.handleAnyMessage(message, completion: { _ in  completion?() })
			} else {
				self.deliverActionEventToUser(
					message: nil,
					action: NotificationAction.defaultAction,
					notificationUserInfo: localNotification.userInfo as? [String: Any] ?? [:],
					completion: { completion?() }
				)
			}
		}
	}
	
	func handleAction(identifier: String?, categoryId: String?, message: MTMessage?, notificationUserInfo: [String: Any]?, responseInfo: [AnyHashable: Any]?, completionHandler: @escaping () -> Void) {
		
		MMLogDebug("[Interaction Service] handling action \(identifier ?? "n/a") for message \(message?.messageId ?? "n/a"), resonse info \(responseInfo ?? [:])")
		
		guard isRunning, let identifier = identifier else {
			MMLogWarn("[Interaction Service] canceled handling")
			completionHandler()
			return
		}

		if (categoryId?.isEmpty ?? true) {
			if MobileMessaging.application.applicationState != .active {
				InteractiveMessageAlert.sharedInstance.cancelAllAlerts()
			}
		} else {
			if identifier != NotificationAction.DefaultActionId && MobileMessaging.application.applicationState != .active {
				InteractiveMessageAlert.sharedInstance.cancelAllAlerts()
			}
		}
		
		let handleAction: (NotificationAction) -> Void = { action in
			message?.appliedAction = action
			if let message = message {
				self.mmContext.messageHandler.handleMTMessage(
					message,
					notificationTapped: action.isTapOnNotificationAlert,
					completion: { _ in completionHandler() }
				)
			} else {
				self.deliverActionEventToUser(
					message: nil,
					action: action,
					notificationUserInfo: notificationUserInfo,
					completion: { completionHandler() }
				)
			}
		}	
		
		if identifier == NotificationAction.DismissActionId
		{
			MMLogDebug("[Interaction Service] handling dismiss action")
			handleAction(NotificationAction.dismissAction)
		}
		else if identifier == NotificationAction.DefaultActionId
		{
			MMLogDebug("[Interaction Service] handling default action")
			handleAction(NotificationAction.defaultAction)
		}
		else if	let categoryId = categoryId,
			let category = allNotificationCategories?.first(where: { $0.identifier == categoryId }),
			let action = category.actions.first(where: { $0.identifier == identifier })
		{
			if	#available(iOS 9.0, *),
				let responseInfo = responseInfo,
				let action = action as? TextInputNotificationAction,
				let typedText = responseInfo[UIUserNotificationActionResponseTypedTextKey] as? String
			{
				MMLogDebug("[Interaction Service] handling text input")
				action.typedText = typedText
				handleAction(action)
			} else {
				MMLogDebug("[Interaction Service] handling regular action")
				handleAction(action)
			}
		}
		else {
			MMLogDebug("[Interaction Service] nothing to handle")
			completionHandler()
		}
	}
	
	//MARK: - Protocol requirements (MobileMessagingService)
	var isRunning: Bool = false
	
	fileprivate func postActionEventNotifications(_ appliedAction: NotificationAction, message: MTMessage?, notificationUserInfo: [String: Any]?) {
		let name: String
		
		var userInfo = [
			MMNotificationKeyMessage: message as Any,
			MMNotificationKeyNotificationUserInfo: notificationUserInfo as Any,
			MMNotificationKeyActionIdentifier: appliedAction.identifier
			] as [String: Any]
		
		if appliedAction.isTapOnNotificationAlert {
			name = MMNotificationMessageTapped
		} else {
			if #available(iOS 9.0, *), let text = (appliedAction as? TextInputNotificationAction)?.typedText {
				userInfo[MMNotificationKeyActionTextInput] = text
			}
			name = MMNotificationActionTapped
		}
		NotificationCenter.mm_postNotificationFromMainThread(name: name, userInfo: userInfo)
	}
	
	func deliverActionEventToUser(message: MTMessage?, action: NotificationAction, notificationUserInfo: [String: Any]?, completion: @escaping () -> Void) {
		postActionEventNotifications(action, message: message, notificationUserInfo: notificationUserInfo)
		MobileMessaging.messageHandlingDelegate?.didPerform(action: action, forMessage: message, notificationUserInfo: notificationUserInfo) { completion() }
			?? completion()
	}
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
	
	func handleNewMessage(_ message: MTMessage, completion: ((MessageHandlingResult) -> Void)?) {
		if 	message.showInApp &&
			(
				(message.category != nil && message.appliedAction?.identifier == NotificationAction.DefaultActionId) ||
				message.appliedAction == nil
			)
		{
			InteractiveMessageAlert.sharedInstance.showInteractiveAlert(forMessage: message, exclusively: MobileMessaging.application.applicationState == .background)
		}
		completion?(.noData)
	}
	
	func handleAnyMessage(_ message: MTMessage, completion: ((MessageHandlingResult) -> Void)?) {
		guard isRunning, let appliedAction = message.appliedAction else {
			completion?(.noData)
			return
		}
		
		let dispatchGroup = DispatchGroup()
		
		dispatchGroup.enter()
		deliverActionEventToUser(message: message,
								 action: appliedAction,
								 notificationUserInfo: message.originalPayload) {
									dispatchGroup.leave()
		}
		
		dispatchGroup.enter()
		self.mmContext.setSeenImmediately([message.messageId]) { _ in
			dispatchGroup.leave()
		}
		
		if appliedAction.options.contains(.moRequired) {
			let mo = MOMessage(
				destination: nil,
				text: "\(message.category ?? "n/a") \(appliedAction.identifier)",
				customPayload: nil,
				composedDate: MobileMessaging.date.now,
				bulkId: message.internalData?[InternalDataKeys.bulkId] as? String,
				initialMessageId: message.messageId
			)
			
			dispatchGroup.enter()
			self.mmContext.sendMessagesSDKInitiated([mo]) { msgs, error in
				dispatchGroup.leave()
			}
		}
		dispatchGroup.notify(queue: DispatchQueue.global(qos: .default)) {
			completion?(.noData)
		}
	}
	
	func syncWithServer(_ completion: ((NSError?) -> Void)?) {
		self.mmContext.retryMoMessageSending() { (_, error) in
			completion?(error)
		}
	}
	
	func stop(_ completion: ((Bool) -> Void)? = nil) {
		MMLogDebug("[Interaction Service] stopping")
		isRunning = false
	}
	
	func start(_ completion: ((Bool) -> Void)? = nil) {
		MMLogDebug("[Interaction Service] starting")
		isRunning = true
	}
}
