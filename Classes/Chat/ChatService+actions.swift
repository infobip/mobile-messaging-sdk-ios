// 
//  ChatService.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import WebKit
import UIKit

public extension MMInAppChatService {    
    /// Method for setting the chat language, both in the WKWebView's system messages and the inputs. We'll consider only the left side of a locale and try to recognise the language. If unsupported, English will be set instead. Language must be set before WKWebView is loaded or presented.
    @objc func setLanguage(_ localeString: String) {
        let separator = localeString.contains("_") ? "_" : "-"
        let components = localeString.components(separatedBy: separator)
        MMLanguage.sessionLanguage = MMLanguage.mapLanguage(from: components.first ??
                                                         String(localeString.prefix(2)))
        MMChatSettings.sharedInstance.postAppearanceChangedNotification()
    }
    
    ///  Send contextual metadata and an InAppChatMultiThreadFlag flag
    ///
    /// - Parameter metadata: Contextual data in JSON format.
    /// - Parameter multiThreadStrategy: `ALL` metadata sent to all non-closed conversations for a widget. `ACTIVE` metadata sent to active only conversation for a widget.
    func sendContextualData(
        _ metadata: String,
        multiThreadStrategy: MMChatMultiThreadStrategy = .ACTIVE
    ) {
        guard let webViewDelegate = webViewDelegate else {
            self.contextualData = ContextualData(metadata: metadata, multiThreadStrategy: multiThreadStrategy)
            return
        }
        
        webViewDelegate.sendContextualData(ContextualData(metadata: metadata, multiThreadStrategy: multiThreadStrategy))
    }

    internal func handleOpenLiveChatAction(
        _ message: MM_MTMessage,
        attempt: Int,
        completion: @escaping (MessageHandlingResult) -> Void
    ) {

        // If there is no widget available, we retry a few times. This can be needed if for example the app was killed
        guard let chatWidget = chatWidget else {
            guard attempt < 4 else {
                logError("Widget not found. In-App action could not open LiveChat")
                completion(.noData)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
               self?.handleOpenLiveChatAction(message, attempt: attempt + 1, completion: completion)
            }
            return
        }
        // We present the widget first, asap, for optimal UX. Widget will display loading state and further actions are async.
        self.displayLiveChat(for: message) { [weak self] chatVC in
            // If there is no keyword, the flow ends as there is nothing to send 
            guard let keyword = message.openLiveChatKeyword else {
                guard chatWidget.multiThread ?? false else {
                    completion(.noData)
                    return
                }
                // Pure UI method, has no actual effect in the threads: just navigates to "single thread view"
                self?.showSingleThreadUI(in: chatWidget, chatVC: chatVC, completion: {
                    completion(.noData)
                })
                return
            }
            self?.sendLCMessage(keyword, to: chatWidget, chatVC: chatVC) {
                MobileMessaging.messageHandlingDelegate?.inAppOpenLiveChatActionTapped?(for: message)
                completion(.noData)
            }
        }
    }

    private func displayLiveChat(
        for message: MM_MTMessage,
        attempt: Int = 0,
        completion: @escaping (MMChatViewController?) -> Void)
    {
        DispatchQueue.mmEnsureMain {
            // If the 'openingLivechat' delegate method below is implemented, the chat won't be presented, as the event will be delegated to the parent app. This allows choosing where the chat is presented, how is presented (in a root navigation bar, as modal, SUI HostingVC, etc.), and what input composer will be used (allowing a total replacement). Otherwise, default chat view controller (as full size navigation child VC) will be pushed in the navigation of the top view controller, if found. Nevertheless, a payload will be sent if it exists.
            guard MobileMessaging.messageHandlingDelegate?.inAppOpenLiveChatActionTapped == nil else {
                self.logDebug("In-App action to open LiveChat: presentation delegated")
                completion(nil)
                return
            }

            guard MobileMessaging.inAppChat?.webViewDelegate == nil else {
                self.logDebug("In-App action to open LiveChat: ChatViewController already loaded by parent app.")
                completion(MobileMessaging.inAppChat?.webViewDelegate as? MMChatViewController)
                return
            }

            guard let presenterVC = MobileMessaging.messageHandlingDelegate?.inAppPresentingViewController?(for: message)
                    ?? MobileMessaging.application.visibleViewController else {
                // We allow a few retries, in 1 second intervals, in case MobileMessaging.application.visibleViewController was not initialized on time
                guard attempt < 3 else {
                    self.logError("In-App action to open LiveChat: Unable to present chat as there is no navigation controller available (attempt 1/\(attempt)")
                    completion(nil)
                    return
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                   self.displayLiveChat(for: message, attempt: attempt + 1, completion: completion)
                }
                return
            }

            let chatNavVC = MMChatViewController.makeRootNavigationViewController()
            chatNavVC.navigationBar.backgroundColor = MMChatSettings.sharedInstance.backgroundColor
            chatNavVC.view.backgroundColor = MMChatSettings.sharedInstance.backgroundColor
            chatNavVC.modalPresentationStyle = .fullScreen
            presenterVC.present(chatNavVC, animated: true) {
                self.logDebug("Chat view controller was presented after open LiveChat action.")
                completion(chatNavVC.viewControllers.first as? MMChatViewController)
            }
        }
    }

    internal func reloadChat()
    {
        guard chatWidget != nil else { return }
        if let chatVC = MobileMessaging.application.visibleViewController as? MMChatViewController {
            chatVC.reset()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                chatVC.restartConnection()
            }
        }
        if isUsingAPI {
            self.api.reset()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.api.restartConnection()
            }
        }
    }

    private func sendLCMessage(
        _ keyword: String,
        to chatWidget: ChatWidget,
        chatVC: MMChatViewController?,
        completion: @escaping () -> Void)
    {
        // We check for a VC to send the commants into. This avoids using the API, which would need to load a separate webview, resulting in slower UX
        let apiInterface: MMChatBasicWebViewActions? = (chatVC ?? api)
        DispatchQueue.main.async { [weak self] in // ensure API is called on MT
            guard chatWidget.multiThread ?? false else {
                // No new thread needed, we just send payload
                apiInterface?.send(keyword.livechatBasicPayload) { error in
                    if let error = error {
                        self?.logError("Failure when sending LiveChat message \(keyword) on widgetId \(chatWidget.id): error \(error.localizedDescription)")
                    }
                    completion()
                }
                return
            } // Otherwise we create thread with payload
            apiInterface?.createThread(keyword.livechatBasicPayload) { thread, error in
                if let error = error {
                    self?.logError("Failure when creating LiveChat thread with \(keyword) on widgetId \(chatWidget.id): error \(error.localizedDescription)")
                }
                completion()
            }
        }
    }

    private func showSingleThreadUI(
        in chatWidget: ChatWidget,
        chatVC: MMChatViewController?,
        completion: @escaping () -> Void)
    {
        // We check for a VC to send the commants into. This avoids using the API, which would need to load a separate webview, resulting in slower UX
        let apiInterface: MMChatInternalWebViewActions? = (chatVC ?? (api as? MMChatInternalWebViewActions))
        DispatchQueue.main.async { [weak self] in
            apiInterface?.openNewThread() { [weak self] error in
                if let error = error {
                    self?.logError("Failure when opening single thread view in LiveChat widgetId \(chatWidget.id): error \(error.localizedDescription)")
                }
                completion()
            }
        }
    }
    
    func validateSetup() {
        var error: MMChatLocalError?
        if mmContext.currentInstallation().pushRegistrationId == nil {
            error = .noPushRegistrationId
        } else if chatWidget == nil {
            error = .noWidget
        }
        
        guard let error = error else { return }
        Task { @MainActor in
            cleanEmptyReceiverWrappers() // the receivers list is wiped out once the widget is received, but here we just clean those that were deallocated from parent app (in case setup is validated later, and valid receivers are listening)
            installationReceivers.forEach {
                $0.value?.didDetectWrongSetup(error) // installationsReceives are cleaned after getting the widget, thus validating the setup
            }
        }
    }
}

struct ContextualData {
    var metadata: String
    var multiThreadStrategy: MMChatMultiThreadStrategy
}

protocol WidgetSubscriber: AnyObject {
    func didLoad(_ widget: ChatWidget)
    func didReceive(_ errors: MMChatRemoteError)
    func didDetectWrongSetup(_ localError: MMChatLocalError)
}

class WidgetSubscriberWeak {
    weak var value: WidgetSubscriber?
    init(_ value: WidgetSubscriber) {
        self.value = value
    }
}

protocol ChatWebViewDelegate: AnyObject, WidgetSubscriber {
    func didEnableControls(_ enabled: Bool)
    func didShowComposeBar(_ visible: Bool)
    func didOpenPreview(forAttachment attachment: ChatWebAttachment)
    func didChangeView(_ state: MMChatWebViewState)
    func sendContextualData(_ contextualData: ContextualData)
}

@objc public protocol MMInAppChatDelegate {
	///In-app Chat can be disabled or not bind to the application on the Infobip portal. In these cases `enabled` will be `false`.
	///You can use this, for example, to show or hide chat button for the user.
    @objc optional func inAppChatIsEnabled(_ enabled: Bool)
    
    ///Called whenever a new chat push message arrives, contains current unread message counter value
    @objc optional func didUpdateUnreadMessagesCounter(_ count: Int)

    ///Called whenever an attachment exceeds the max allowed size and cannot be uploaded. If undefined, a localised alert will be displayed instead
    @objc optional func attachmentSizeExceeded(_ maxSize: UInt)

    ///Called whenever a text exceeds the max allowed lenght and cannot be sent.
    @objc optional func textLengthExceeded(_ maxLength: UInt)

    ///Called for informing about what view the chat is presenting. This is useful if your widget supports multiple
    ///threads, in which case you may want to hide the keyboard if something else than the chat view is presented
    @objc optional func chatDidChange(to state: MMChatWebViewState)

    ///Called for informing about an exception received from the widget, either upon loading or after a request from client side.
    ///You can decide (by returning a MMChatExceptionDisplayMode value) if the default error banner is presented for the exception, or you prefer to display an error UI of your own
    @objc optional func didReceiveException(_ exception: MMChatException) -> MMChatExceptionDisplayMode

    ///Called when the SDK needs a JSON Web Token from your end. This method is only needed if your widget requires JWT for authentication, as defined on its setup. Keep in mind each JWT you provide must be different from the previous one.
    ///Note: this method is predictable: it will be triggered only when a new chat view (or navigation) controller is created, or the first time you use an API method.
    @objc optional func getJWT() -> String?
}

extension UserEventsManager {
    class func postInAppChatAvailabilityUpdatedEvent(_ inAppChatEnabled: Bool) {
        post(MMNotificationInAppChatAvailabilityUpdated, [MMNotificationKeyInAppChatEnabled: inAppChatEnabled])
    }
    
    class func postInAppChatUnreadMessagesCounterUpdatedEvent(_ counter: Int) {
        post(MMNotificationInAppChatUnreadMessagesCounterUpdated, [MMNotificationKeyInAppChatUnreadMessagesCounter: counter])
    }

    class func postInAppChatViewChangedEvent(_ viewState: String) {
        post(MMNotificationInAppChatViewChanged, [MMNotificationKeyInAppChatViewChanged: viewState])
    }

    class func postChatRegistrationReceived(_ registrationId: String) {
        post(MMNotificationChatRegistrationReceived,
             [MMNotificationKeyChatRegistrationReceived: registrationId])
    }
}
