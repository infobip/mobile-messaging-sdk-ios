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
	@available(iOS, obsoleted: 10.0, message: "If your apps minimum deployment target is iOS 10 or later, you don't need to forward your App Delegate calls to this method. Handling notifications actions on iOS since 10.0 is done by Mobile Messaging SDK by implementing UNUserNotificationCenterDelegate under the hood.")
	public class func handleActionWithIdentifier(identifier: String?, localNotification: UILocalNotification, responseInfo: [AnyHashable: Any]?, completionHandler: @escaping () -> Void) {}

	/// This method handles interactive notifications actions and performs work that is defined for this action. The method should be called from AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)` callback.
	///
	/// - parameter identifier: The identifier for the interactive notification action.
	/// - parameter userInfo: A dictionary that contains information related to the remote notification. This dictionary originates from the provider as a JSON-defined dictionary, which iOS converts to an NSDictionary object before calling this method. The contents of the dictionary are the remote notification payload, which consists only of property-list objects plus NSNull
	/// - parameter responseInfo: The data dictionary sent by the action. Potentially could contain text entered by the user in response to the text input action.
	/// - parameter completionHandler: A block that you must call when you are finished performing the action. It is originally passed to AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)` callback as a `completionHandler` parameter.
	@available(iOS, obsoleted: 10.0, message: "If your apps minimum deployment target is iOS 10 or later, you don't need to forward your App Delegate calls to this method. Handling notifications actions on iOS since 10.0 is done by Mobile Messaging SDK by implementing UNUserNotificationCenterDelegate under the hood.")
	public class func handleActionWithIdentifier(identifier: String?, forRemoteNotification userInfo: [AnyHashable: Any], responseInfo: [AnyHashable: Any]?, completionHandler: @escaping () -> Void) {}

	/// This method handles interactive notifications actions and performs work that is defined for this action.
	///
	/// - parameter identifier: The identifier for the interactive notification action.
	/// - parameter message: The `MTMessage` object the action associated with.
	/// - parameter responseInfo: The data dictionary sent by the action. Potentially could contain text entered by the user in response to the text input action.
	/// - parameter completionHandler: A block that you must call when you are finished performing the action.
	class func handleAction(identifier: String?, category: String?, message: MTMessage?, notificationUserInfo: [String: Any]?, userText: String?, completionHandler: @escaping () -> Void) {
		guard let service = NotificationsInteractionService.sharedInstance, let actionId = identifier else
		{
			MMLogWarn("[NotificationsInteractionService] canceled handling actionId \(identifier ?? "nil"), service is initialized \(NotificationsInteractionService.sharedInstance != nil)")
			completionHandler()
			return
		}

		service.handleAction(identifier: actionId, categoryId: category, message: message, notificationUserInfo: notificationUserInfo, userText: userText, completionHandler: completionHandler)
	}

	/// Returns `NotificationCategory` object for provided category Id. Category Id can be obtained from `MTMessage` object with `MTMessage.category` method.
	/// - parameter identifier: The identifier associated with the category of interactive notification
	public class func category(withId identifier: String) -> NotificationCategory? {
		return NotificationsInteractionService.sharedInstance?.allNotificationCategories?.first(where: {$0.identifier == identifier})
	}
}

class NotificationsInteractionService: MobileMessagingService {
	let customNotificationCategories: Set<NotificationCategory>?

	var allNotificationCategories: Set<NotificationCategory>? {
		return customNotificationCategories + NotificationCategories.predefinedCategories
	}

	static var sharedInstance: NotificationsInteractionService?

	init(mmContext: MobileMessaging, categories: Set<NotificationCategory>?) {
		self.customNotificationCategories = categories
		super.init(mmContext: mmContext, id: "com.mobile-messaging.subservice.NotificationsInteractionService")
	}

	func handleAction(identifier: String, categoryId: String?, message: MTMessage?, notificationUserInfo: [String: Any]?, userText: String?, completionHandler: @escaping () -> Void) {

		MMLogDebug("[NotificationsInteractionService] handling action \(identifier) for message \(message?.messageId ?? "n/a"), user text empty \(userText?.isEmpty ?? true)")

		guard isRunning else {
			MMLogWarn("[NotificationsInteractionService] cancelled handling, service stopped")
			completionHandler()
			return
		}

		if (categoryId?.isEmpty ?? true) {
			if MobileMessaging.application.applicationState != .active {
				mmContext.interactiveAlertManager.cancelAllAlerts()
			}
		} else {
			if identifier != NotificationAction.DefaultActionId && MobileMessaging.application.applicationState != .active {
				mmContext.interactiveAlertManager.cancelAllAlerts()
			}
		}

		if let action = makeAction(identifier, message, categoryId, userText) {
			if let message = message {
				message.appliedAction = action
				self.mmContext.messageHandler.handleMTMessage(message, notificationTapped: action.isTapOnNotificationAlert, completion: { _ in completionHandler() })
			} else {
				self.deliverActionEventToUser(message: nil, action: action, notificationUserInfo: notificationUserInfo, completion: { completionHandler() })
			}
		} else {
			completionHandler()
		}
	}

	static func presentInAppWebview(_ urlString: String, _ presentingVc: UIViewController, _ message: MTMessage) {
		let webViewController = WebViewController(url: urlString)
		webViewController.modalPresentationStyle = .fullScreen
		MobileMessaging.messageHandlingDelegate?.inAppWebViewWillShowUp?(webViewController, for: message)
		presentingVc.present(webViewController, animated: true, completion: nil)
	}

	fileprivate func handleNotificationTap(message: MTMessage, completion: @escaping () -> Void) {
		DispatchQueue.main.async {
			if let urlString = message.webViewUrl?.absoluteString, let presentingVc = MobileMessaging.messageHandlingDelegate?.inAppWebViewPresentingViewController?(for: message) {
				NotificationsInteractionService.presentInAppWebview(urlString, presentingVc, message)
            } else if let browserUrl = message.browserUrl,
                UIApplication.shared.canOpenURL(browserUrl) {
                UIApplication.shared.open(browserUrl)
            }
			completion()
		}
	}

	fileprivate func makeAction(_ identifier: String?, _ message: MTMessage?, _ categoryId: String?, _ userText: String?) -> NotificationAction? {
		if identifier == NotificationAction.DismissActionId
		{
			MMLogDebug("[NotificationsInteractionService] handling dismiss action")
			return NotificationAction.dismissAction()
		}
		else if identifier == NotificationAction.DefaultActionId
		{
			MMLogDebug("[NotificationsInteractionService] handling default action")
			return NotificationAction.defaultAction
		}
		else if	let categoryId = categoryId,
			let category = allNotificationCategories?.first(where: { $0.identifier == categoryId }),
			let action = category.actions.first(where: { $0.identifier == identifier })
		{
			if
				let action = action as? TextInputNotificationAction,
				let typedText = userText
			{
				MMLogDebug("[NotificationsInteractionService] handling text input")
				action.typedText = typedText
				return action
			} else {
				MMLogDebug("[NotificationsInteractionService] handling regular action")
				return action
			}
		}
		else {
			MMLogDebug("[NotificationsInteractionService] nothing to handle")
			return nil
		}
	}

	fileprivate func deliverActionEventToUser(message: MTMessage?, action: NotificationAction, notificationUserInfo: [String: Any]?, completion: @escaping () -> Void) {
		var userInfo = [
			MMNotificationKeyMessage: message as Any,
			MMNotificationKeyNotificationUserInfo: notificationUserInfo as Any,
			MMNotificationKeyActionIdentifier: action.identifier
			] as [String: Any]

		if action.isTapOnNotificationAlert {
			UserEventsManager.postMessageTappedEvent(userInfo)
		} else {
			if let text = (action as? TextInputNotificationAction)?.typedText {
				userInfo[MMNotificationKeyActionTextInput] = text
			}
			UserEventsManager.postActionTappedEvent(userInfo)
		}

		MobileMessaging.messageHandlingDelegate?.didPerform?(action: action, forMessage: message, notificationUserInfo: notificationUserInfo) { completion() }
			?? completion()
	}

	override func mobileMessagingDidStop(_ mmContext: MobileMessaging) {
		stop({_ in })
		NotificationsInteractionService.sharedInstance = nil
	}

	override func mobileMessagingDidStart(_ mmContext: MobileMessaging) {
		guard let cs = allNotificationCategories, !cs.isEmpty else {
			return
		}
		start({_ in })
	}

	override func handleNewMessage(_ message: MTMessage, completion: @escaping (MessageHandlingResult) -> Void) {
		mmContext.interactiveAlertManager.showModalNotificationIfNeeded(forMessage: message)
		completion(.noData)
	}

	override func handleAnyMessage(_ message: MTMessage, completion: @escaping (MessageHandlingResult) -> Void) {
		guard isRunning, let appliedAction = message.appliedAction else {
			completion(.noData)
			return
		}

		let dispatchGroup = DispatchGroup()

		if message.appliedAction?.isTapOnNotificationAlert ?? false {
			dispatchGroup.enter()
			handleNotificationTap(message: message, completion: {
				dispatchGroup.leave()
			})
		}

		dispatchGroup.enter()
		deliverActionEventToUser(message: message, action: appliedAction, notificationUserInfo: message.originalPayload, completion: { dispatchGroup.leave()
		})

		dispatchGroup.enter()
		self.mmContext.setSeen([message.messageId], immediately: true, completion: {
			dispatchGroup.leave()
		})

		if appliedAction.options.contains(.moRequired) {
			let mo = MOMessage(
				destination: nil,
				text: "\(message.category ?? "n/a") \(appliedAction.identifier)",
				customPayload: nil,
				composedDate: MobileMessaging.date.now,
				bulkId: message.internalData?[Consts.InternalDataKeys.bulkId] as? String,
				initialMessageId: message.messageId
			)

			dispatchGroup.enter()
			self.mmContext.sendMessagesSDKInitiated([mo]) { msgs, error in
				dispatchGroup.leave()
			}
		}
		dispatchGroup.notify(queue: DispatchQueue.global(qos: .default)) {
			completion(.noData)
		}
	}

	override func appWillEnterForeground(_ n: Notification) {
		syncWithServer({_ in})
	}

	override func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
		self.mmContext.retryMoMessageSending() { (_, error) in
			completion(error)
		}
	}
}
