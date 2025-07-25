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
    public func withInteractiveNotificationCategories(_ categories: Set<MMNotificationCategory>) -> MobileMessaging {
        if !categories.isEmpty {
            self.notificationsInteractionService = NotificationsInteractionService(mmContext: self, categories: categories)
        }
        return self
    }
    
    /// This method handles interactive notifications actions and performs work that is defined for this action.
    ///
    /// - parameter identifier: The identifier for the interactive notification action.
    /// - parameter message: The `MM_MTMessage` object the action associated with.
    /// - parameter responseInfo: The data dictionary sent by the action. Potentially could contain text entered by the user in response to the text input action.
    /// - parameter completionHandler: A block that you must call when you are finished performing the action.
    public class func handleAction(identifier: String?, category: String?, message: MM_MTMessage?, notificationUserInfo: [String: Any]?, userText: String?, completionHandler: @escaping () -> Void) {
        guard let mm = MobileMessaging.sharedInstance, let service = mm.notificationsInteractionService, let actionId = identifier else
        {
            MMLogWarn("[NotificationsInteractionService] canceled handling actionId \(identifier ?? "nil"), service is initialized \(MobileMessaging.sharedInstance?.notificationsInteractionService != nil)")
            completionHandler()
            return
        }
        mm.queue.async {
            service.handleAction(userInitiated: false, identifier: actionId, categoryId: category, message: message, notificationUserInfo: notificationUserInfo, userText: userText, completionHandler: completionHandler)
        }
    }
    
    /// Returns `MMNotificationCategory` object for provided category Id. Category Id can be obtained from `MM_MTMessage` object with `MTMessage.category` method.
    /// - parameter identifier: The identifier associated with the category of interactive notification
    public class func category(withId identifier: String) -> MMNotificationCategory? {
        return MobileMessaging.sharedInstance?.notificationsInteractionService?.allNotificationCategories?.first(where: {$0.identifier == identifier})
    }
}

public class NotificationsInteractionService: MobileMessagingService {
    let customNotificationCategories: Set<MMNotificationCategory>?
    
    var allNotificationCategories: Set<MMNotificationCategory>? {
        return customNotificationCategories + NotificationCategories.predefinedCategories
    }
    
    init(mmContext: MobileMessaging, categories: Set<MMNotificationCategory>?) {
        self.customNotificationCategories = categories
        super.init(mmContext: mmContext, uniqueIdentifier: "NotificationsInteractionService")
    }
    
    func handleAction(userInitiated: Bool, identifier: String, categoryId: String?, message: MM_MTMessage?, notificationUserInfo: [String: Any]?, userText: String?, completionHandler: @escaping () -> Void) {
        logDebug("Handling action - User Initiated: \(userInitiated), Identifier: \(identifier), Category ID: \(categoryId ?? "n/a"), User Text: \(userText ?? "n/a"), Message ID: \(message?.messageId ?? "n/a")")

        guard isRunning else {
            logWarn("cancelled handling, service stopped")
            completionHandler()
            return
        }
        
        if let message = message {
            reportClickIfInAppMessage(message: message, identifier: identifier)
        }
        
        if (categoryId?.isEmpty ?? true) {
            if MobileMessaging.application.applicationState != .active {
                mmContext.interactiveAlertManager.cancelAllAlerts()
            }
        } else {
            if identifier != MMNotificationAction.DefaultActionId && MobileMessaging.application.applicationState != .active {
                mmContext.interactiveAlertManager.cancelAllAlerts()
            }
        }
        
        if let action = makeAction(identifier, message, categoryId, userText) {
            if let message = message {
                message.appliedAction = action
                self.mmContext.messageHandler.handleMTMessage(userInitiated: userInitiated, message: message, notificationTapped: action.isTapOnNotificationAlert, completion: { _ in completionHandler() })
            } else {
                self.deliverActionEventToUser(message: nil, action: action, notificationUserInfo: notificationUserInfo, completion: { completionHandler() })
            }
        } else {
            completionHandler()
        }
    }
    
    public static func presentInAppWebview(_ urlString: String, _ presentingVc: UIViewController, _ message: MM_MTMessage?) {
        let webViewController = MMWebViewController(url: urlString)
        webViewController.modalPresentationStyle = .fullScreen
        webViewController.applySettings(MobileMessaging.sharedInstance?.webViewSettings)
        if let message = message {
            MobileMessaging.messageHandlingDelegate?.inAppWebViewWillShowUp?(webViewController, for: message)
        }
        presentingVc.present(webViewController, animated: true, completion: nil)
    }
    
    private func reportClickIfInAppMessage(message: MM_MTMessage, identifier: String) {
        if let inAppMessage = MMInAppMessage(from: message) {
            logDebug("action is being handled for an inapp, inAppDetails - url: \(inAppMessage.url), clickUrl: \(inAppMessage.clickUrl?.absoluteString ?? "clickurl empty"), type: \(inAppMessage.type), position: \(inAppMessage.position.map { "\($0.rawValue)" } ?? "position empty")")
            
            if identifier == MMNotificationAction.PrimaryActionId || identifier == MMNotificationAction.DefaultActionId {
                if let clickUrl = inAppMessage.clickUrl?.absoluteString {
                    self.mmContext.webInAppClickService?.submitWebInAppClick(clickUrl: clickUrl, buttonIdx: inAppMessage.type.buttonIdx, completion: {_ in})
                }
            }
        }
    }
    
    func isUrlDomainTrusted(_ url: URL) -> Bool {
        guard let trustedDomains = mmContext.trustedDomains, !trustedDomains.isEmpty else {
            return true
        }
        
        guard let host = url.host else {
            return false
        }
        
        for trustedDomain in trustedDomains {
            if host == trustedDomain || host.hasSuffix("."+trustedDomain) {
                return true
            }
        }
        
        return false
    }
    
    fileprivate func handleNotificationTap(message: MM_MTMessage, attempt: Int = 0, completion: @escaping () -> Void) {
        logDebug("handleNotificationTap")
        guard attempt < 3 else {
            completion()
            return
        }
        DispatchQueue.main.async {
            let delegate = MobileMessaging.messageHandlingDelegate
            if let urlString = message.webViewUrl?.absoluteString {
                if let url = URL(string: urlString), url.scheme != "http", url.scheme != "https" {
                    // For non-HTTP/HTTPS URLs (deeplinks), don't apply domain validation
                    if (UIApplication.shared.canOpenURL(url)) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                } else if let url = URL(string: urlString), self.isUrlDomainTrusted(url) {
                    // For HTTP/HTTPS URLs, apply domain validation before opening in webview
                    if let presentingVc = delegate?.inAppPresentingViewController?(for: message) ??
                                MobileMessaging.application.visibleViewController {
                        NotificationsInteractionService.presentInAppWebview(urlString, presentingVc, message)
                    } else {
                        // We retry handleNotificationTap because there might be a condition when MobileMessaging.application.visibleViewController
                        // is not yet initialized in the app that is being started by user tapping on notification
                        // we do 2 additional attempts with 1 second interval.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.handleNotificationTap(message: message, attempt: attempt + 1, completion: {})
                        }
                    }
                } else {
                    self.logWarn("WebView URL domain is not trusted and will not be opened: \(urlString)")
                }
            } else if let browserUrl = message.browserUrl, (delegate?.shouldOpenInBrowser?(browserUrl) ?? true),
                      self.isUrlDomainTrusted(browserUrl), UIApplication.shared.canOpenURL(browserUrl) {
                UIApplication.shared.open(browserUrl)
            } else if let browserUrl = message.browserUrl, !self.isUrlDomainTrusted(browserUrl) {
                self.logWarn("Browser URL domain is not trusted and will not be opened: \(browserUrl.absoluteString)")
            }
        }
        completion()
    }
    
    fileprivate func makeAction(_ identifier: String?, _ message: MM_MTMessage?, _ categoryId: String?, _ userText: String?) -> MMNotificationAction? {
        if identifier == MMNotificationAction.DismissActionId
        {
            logDebug("handling dismiss action")
            return MMNotificationAction.dismissAction()
        }
        else if identifier == MMNotificationAction.DefaultActionId
        {
            logDebug("handling default action")
            return MMNotificationAction.defaultAction
        }
        else if identifier == MMNotificationAction.PrimaryActionId
        {
            logDebug("handling primary action")
            return MMNotificationAction.primaryAction
        }
        else if	let categoryId = categoryId,
                let category = allNotificationCategories?.first(where: { $0.identifier == categoryId }),
                let action = category.actions.first(where: { $0.identifier == identifier })
        {
            if
                let action = action as? MMTextInputNotificationAction,
                let typedText = userText
            {
                logDebug("handling text input")
                action.typedText = typedText
                return action
            } else {
                logDebug("handling regular action")
                return action
            }
        }
        else {
            logDebug("nothing to handle")
            return nil
        }
    }
    
    fileprivate func deliverActionEventToUser(message: MM_MTMessage?, action: MMNotificationAction, notificationUserInfo: [String: Any]?, completion: @escaping () -> Void) {
        var userInfo = [
            MMNotificationKeyMessage: message as Any,
            MMNotificationKeyNotificationUserInfo: notificationUserInfo as Any,
            MMNotificationKeyActionIdentifier: action.identifier
        ] as [String: Any]
        
        if action.isTapOnNotificationAlert {
            UserEventsManager.postMessageTappedEvent(userInfo)
        } else {
            if let text = (action as? MMTextInputNotificationAction)?.typedText {
                userInfo[MMNotificationKeyActionTextInput] = text
            }
            UserEventsManager.postActionTappedEvent(userInfo)
        }
        
        MobileMessaging.messageHandlingDelegate?.didPerform?(action: action, forMessage: message, notificationUserInfo: notificationUserInfo) { completion() }
        ?? completion()
    }
    
    public override func mobileMessagingWillStart(_ completion: @escaping () -> Void) {
        guard let cs = allNotificationCategories, !cs.isEmpty else {
            completion()
            return
        }
        start({_ in completion() })
    }
    
    public override func start(_ completion: @escaping (Bool) -> Void) {
        assert(!Thread.isMainThread)
        super.start(completion)
        syncWithServer({_ in})
    }
    
    public override func handleNewMessage(_ message: MM_MTMessage, completion: @escaping (MessageHandlingResult) -> Void) {
        mmContext.interactiveAlertManager.showModalNotificationAutomatically(forMessage: message)
        completion(.noData)
    }
    
    public override func handleAnyMessage(_ message: MM_MTMessage, completion: @escaping (MessageHandlingResult) -> Void) {
        guard isRunning, let appliedAction = message.appliedAction else {
            completion(.noData)
            return
        }
        
        let dispatchGroup = DispatchGroup()
        
        if message.appliedAction?.isTapOnNotificationAlert ?? false ||
            message.appliedAction?.identifier == MMNotificationAction.PrimaryActionId {
            logDebug("Message has applied action with identifier \(String(describing: appliedAction.identifier))")
            dispatchGroup.enter()
            handleNotificationTap(message: message, completion: {
                dispatchGroup.leave()
            })
        }
        
        dispatchGroup.enter()
        deliverActionEventToUser(message: message, action: appliedAction, notificationUserInfo: message.originalPayload, completion: { dispatchGroup.leave()
        })
        
        dispatchGroup.enter()
        self.mmContext.setSeen(userInitiated: false, messageIds: [message.messageId], immediately: true, completion: {
            dispatchGroup.leave()
        })
        
        if appliedAction.options.contains(.moRequired) {
            let mo = MM_MOMessage(
                destination: nil,
                text: "\(message.category ?? "n/a") \(appliedAction.identifier)",
                customPayload: message.customPayload,
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
    
    public override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
        syncWithServer({_ in completion() })
    }
    
    func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
        assert(!Thread.isMainThread)
        self.mmContext.retryMoMessageSending() { (_, error) in
            completion(error)
        }
    }
}
