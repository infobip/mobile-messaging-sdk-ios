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

private let chatDefaultTimeout: TimeInterval = 5

public extension MMInAppChatService {    
    /// Method for setting the chat language, both in the WKWebView's system messages and the inputs. We'll consider only the left side of a locale and try to recognise the language. If unsupported, English will be set instead. Language must be set before WKWebView is loaded or presented.
    @objc func setLanguage(_ localeString: String) {
        let separator = localeString.contains("_") ? "_" : "-"
        let components = localeString.components(separatedBy: separator)
        MMLanguage.sessionLanguage = MMLanguage.mapLanguage(from: components.first ??
                                                         String(localeString.prefix(2)))
        MMChatSettings.sharedInstance.postAppearanceChangedNotification()
    }
    
    @available(*, deprecated, message: "Async method 'sendContextualData' needs to be used instead. This method will be removed in a future release")
    func sendContextualData(
        _ metadata: String,
        multiThreadStrategy: MMChatMultiThreadStrategy = .ACTIVE
    ) {
        Task { @MainActor [weak self] in
            await self?.sendContextualData(metadata, multiThreadStrategy: multiThreadStrategy)
        }
    }

    ///  Send contextual metadata and an InAppChatMultiThreadFlag flag
    ///
    /// - Parameter metadata: Contextual data in JSON format.
    /// - Parameter multiThreadStrategy: `ACTIVE` metadata sent to the active conversation only for a widget. `ALL` metadata sent to all non-closed conversations for a widget. `ALL_PLUS_NEW` metadata sent to all non-closed conversations, plus any conversation created afterwards.
    @MainActor
    func sendContextualData(
        _ metadata: String,
        multiThreadStrategy: MMChatMultiThreadStrategy = .ACTIVE
    ) async {
        guard let webViewDelegate = webViewDelegate else {
            self.contextualData = ContextualData(metadata: metadata, multiThreadStrategy: multiThreadStrategy)
            return
        }
        
        let data = ContextualData(metadata: metadata, multiThreadStrategy: multiThreadStrategy)
        do {
            try await webViewDelegate.sendContextualData(data)
        } catch {
            // We keep the data cached afte a failure so it is retried once the widget reaches a valid state again.
            logError("Unable to send contextual data: \(error.localizedDescription)")
            self.contextualData = data
        }
    }

    private func doHandleMessageDelegate(for message: MM_MTMessage) {
        if message.isChatMessage {
            MobileMessaging.messageHandlingDelegate?.inAppInboundLiveChatPushTapped?(for: message)
        } else { // broadcast action
            MobileMessaging.messageHandlingDelegate?.inAppOpenLiveChatActionTapped?(for: message)
        }
    }

    private func isTapHandledByApp(for message: MM_MTMessage) -> Bool {
        if message.isChatMessage {
            return MobileMessaging.messageHandlingDelegate?.inAppInboundLiveChatPushTapped != nil
        }
        return MobileMessaging.messageHandlingDelegate?.inAppOpenLiveChatActionTapped != nil
    }

    @MainActor
    private func handleDelegatedTap(for message: MM_MTMessage) {
        doHandleMessageDelegate(for: message)
        guard !message.isChatMessage, let keyword = message.openLiveChatKeyword else { return }
        Task { @MainActor [weak self] in
            await self?.sendDelegatedBroadcastKeyword(keyword, attempt: 0)
        }
    }

    @MainActor
    private func sendDelegatedBroadcastKeyword(_ keyword: String, attempt: Int) async {
        guard let chatWidget else {
            guard attempt < 10 else {
                logError("Widget not found. LiveChat broadcast keyword could not be sent")
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await sendDelegatedBroadcastKeyword(keyword, attempt: attempt + 1)
            return
        }
        await sendLCMessage(keyword, to: chatWidget, chatDelegate: webViewDelegate)
    }

    @MainActor
    internal func handleOpenLiveChatAction(
        _ message: MM_MTMessage,
        attempt: Int
    ) {
        if isTapHandledByApp(for: message) {
            handleDelegatedTap(for: message)
            return
        }

        // If there is no widget available, we retry a few times. This can be needed if for example the app was killed or network is slow
        guard let chatWidget = chatWidget else {
            guard attempt < 10 else {
                logError("Widget not found. In-App action could not open LiveChat")
                return
            }

            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.handleOpenLiveChatAction(message, attempt: attempt + 1)
            }
            return
        }
        Task { @MainActor [weak self] in
            // We present the widget first, asap, for optimal UX. Widget will display loading state and further actions are async.
            let chatDelegate = await self?.displayLiveChat(for: message)
            if self?.isTapHandledByApp(for: message) ?? false {
                self?.handleDelegatedTap(for: message)
                return
            }
            // If there is a keyword, this is the "broadcast notification with metadata to be sent to the chat" scenario
            if let keyword = message.openLiveChatKeyword {
                await self?.sendLCMessage(keyword, to: chatWidget, chatDelegate: chatDelegate)
            } else if let chatThreadId = message.chatThreadId, chatWidget.multiThread ?? false {
                await self?.navigateToThreadId(chatThreadId, in: chatWidget, chatDelegate: chatDelegate)
            } else if chatWidget.multiThread ?? false, let chatDelegate {
                await self?.showSingleThreadUI(in: chatWidget, chatDelegate: chatDelegate)
            }
        }
    }

    private func delayTask(seconds: UInt) async {
        if #available(iOS 16.0, *) {
            try? await Task.sleep(for: .seconds(seconds))
        } else { // #available left written so this is cleaned in the future when we move out of iOS 15
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    }
    
    @MainActor
    private func displayLiveChat(
        for message: MM_MTMessage,
        attempt: Int = 0) async -> ChatWebViewDelegate?
    {
        if message.isChatMessage {
            guard MobileMessaging.messageHandlingDelegate?.inAppInboundLiveChatPushTapped == nil else {
                self.logDebug("Livechat inbound msg push: presentation delegated")
                return nil
            }
        } else {
            guard MobileMessaging.messageHandlingDelegate?.inAppOpenLiveChatActionTapped == nil else {
                self.logDebug("Livechat open action push: presentation delegated")
                return nil
            }
        }

        if let webViewDelegate {
            self.logDebug("LiveChat tap action: ChatViewController already loaded by parent app.")
            return webViewDelegate
        }

        guard let presenterVC = MobileMessaging.messageHandlingDelegate?.inAppPresentingViewController?(for: message)
                ?? MobileMessaging.application.visibleViewController else {
            // We allow a few retries, in 1 second intervals, in case MobileMessaging.application.visibleViewController was not initialized on time
            guard attempt < 3 else {
                self.logError("In-App action to open LiveChat: Unable to present chat as there is no navigation controller available (attempt \(attempt + 1)/4)")
                return nil
            }
            await delayTask(seconds: 1)
            return await self.displayLiveChat(for: message, attempt: attempt + 1)
        }

        let chatNavVC = MMChatViewController.makeRootNavigationViewController()
        chatNavVC.navigationBar.backgroundColor = MMChatSettings.sharedInstance.backgroundColor
        chatNavVC.view.backgroundColor = MMChatSettings.sharedInstance.backgroundColor
        chatNavVC.modalPresentationStyle = .fullScreen
        return await withCheckedContinuation { (continuation: CheckedContinuation<MMChatViewController?, Never>) in
            let presentation = ChatTimeoutRace(continuation)
            DispatchQueue.main.asyncAfter(deadline: .now() + chatDefaultTimeout) {
                if presentation.finish(with: nil) {
                    self.logError("In-App action to open LiveChat: timed out waiting for chat presentation")
                }
            }
            presenterVC.present(chatNavVC, animated: true) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // This small delay and asyc jump is a safeguard: if the app has been killed and/or the phone was locked, navigation is actually not responsive/trustworthy in same thread execution
                    if presentation.finish(with: chatNavVC.viewControllers.first as? MMChatViewController) {
                        self.logDebug("Chat view controller was presented after open LiveChat action.")
                    }
                }
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

    @MainActor
    private func sendLCMessage(
        _ keyword: String,
        to chatWidget: ChatWidget,
        chatDelegate: ChatWebViewDelegate?) async
    {
        // Use the loaded chat when it implements message actions, avoiding a separate API web view.
        let apiInterface: MMChatBasicWebViewActions = (chatDelegate as? MMChatBasicWebViewActions) ?? api
        let sendingToSingleThread = !(chatWidget.multiThread ?? false)
        do {
            if sendingToSingleThread {
                try await apiInterface.send(keyword.livechatBasicPayload)
            } else { // multithread scenario
                _ = try await apiInterface.createThread(keyword.livechatBasicPayload)
            }
            
        } catch {
            if sendingToSingleThread {
                self.logError("Failure when sending LiveChat message \(keyword) on widgetId \(chatWidget.id): error \(error.localizedDescription)")
            } else { // multithread scenario
                self.logError("Failure when creating LiveChat thread with \(keyword) on widgetId \(chatWidget.id): error \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func navigateToThreadId(
        _ threadId: String,
        in chatWidget: ChatWidget,
        chatDelegate: ChatWebViewDelegate?) async
    {
        guard let chatActions = chatDelegate as? MMLiveChatThreadsActions else {
            self.logError("Unable to open thread \(threadId) from push notification tap: there was not chat view controller available")
            return
        }
        // As opposed to 'sendMessage' method above, this action is purely UI, thus it will not be handled by the API instance in any case.
        do {
            _ = try await chatActions.openThread(with: threadId)
            self.logDebug("Thread \(threadId) was open from push notification tap")
        } catch {
            self.logError("Unable to open thread \(threadId) from push notification tap: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func showSingleThreadUI(
        in chatWidget: ChatWidget,
        chatDelegate: ChatWebViewDelegate) async
    {
        guard let chatActions = chatDelegate as? MMChatInternalWebViewActions else {
            self.logError("Unable to open single thread view in LiveChat widgetId \(chatWidget.id): no chat actions available")
            return
        }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                chatActions.openNewThread { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            self.logError("Failure when opening single thread view in LiveChat widgetId \(chatWidget.id): error \(error.localizedDescription)")
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
    @MainActor func sendContextualData(_ contextualData: ContextualData) async throws
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
    
    ///Called when the user taps a link within a chat message. The returned bool value will determine if the link is opened in the default mobile browser, or ignored. By checking the URI propagated here, you may detect a deeplink and act according to your needs (ie, navigate somewhere within your app vs let the web browser handle it). As soon as the content supports URI query encoding, the content will be allowed: from valid URLs (https://etc), to custom ones (that won't trigger browser opening), such as 'yourAppName://action?data'.
    @objc optional func onChatURIInteracted(_ uri: URL) -> Bool
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
