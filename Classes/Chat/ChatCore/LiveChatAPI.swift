//
//  LiveChatAPI.swift
//  InfobipMobileMessaging
//
//  Created by Maksym Svitlovskyi on 20/02/2025.
//

import Foundation
import WebKit

public protocol MMInAppChatWidgetAPIProtocol: MMChatWebViewActions {
    var delegate: MMInAppChatWidgetAPIDelegate? { get set }

    /// Reset the widget, stop connection and load blank page
    func reset()

    /// Manually preloads the widget. Note: widget state is checked by all other API methods, so this method is not necessary in conjunction with them. You may only need loadWidget() after using reset() above, and in case you just want to listen to incoming widget events.
    func loadWidget()
}
 
public protocol MMInAppChatWidgetAPIDelegate: AnyObject {
    
    /// Receive  errors happened within `MMInAppChatWidgetAPI`
    func didReceiveError(exception: MMChatException)
    
    /// Send changes in `MMNotificationKeyInAppChatViewChanged` of ChatWebView
    func didChangeState(to state: MMChatWebViewState)
    
    func onRawMessageReceived(_ message: Any)
}

class MMInAppChatWidgetAPI: NSObject, MMInAppChatWidgetAPIProtocol, MMChatInternalWebViewActions, NamedLogger {
    private lazy var chatHandler: ChatWebViewHandler = ChatWebViewHandler(eventHandler: self)
    private var didSetOnMessageReceivedListener = false

    weak var delegate: MMInAppChatWidgetAPIDelegate?

    override init() {
        super.init()
        MobileMessaging.inAppChat?.isUsingAPI = true
        loadWidget()
    }

    func loadWidget() {
        DispatchQueue.mmEnsureMain {
            self.chatHandler.webView.navigationDelegate = self
            MMInAppChatService.sharedInstance?.update(for: self)
        }
    }

    func stopConnection() {
        chatHandler.stopConnection()
    }
    
    func restartConnection() {
        chatHandler.restartConnection()
    }
    
    func setLanguage(_ language: MMLanguage, completion: @escaping ((any Error)?) -> Void) {
        chatHandler.setLanguage(language, completion: completion)
    }
    
    func sendDraft(_ message: String?, completion: @escaping ((any Error)?) -> Void) {
        send((message ?? "").livechatDraftPayload, completion: completion)
    }
    
    func sendText(_ text: String, completion: @escaping ((any Error)?) -> Void) {
        send(text.livechatBasicPayload, completion: completion)
    }
    
    func sendAttachment(_ fileName: String?, data: Data, completion: @escaping ((any Error)?) -> Void) {
        let payload = MMLivechatBasicPayload(fileName: fileName, data: data)
        send(payload, completion: completion)
    }

    func send(_ payload: any MMLivechatPayload, completion: @escaping ((any Error)?) -> Void) {
        chatHandler.send(payload, completion: completion)
    }

    func createThread(_ payload: any MMLivechatPayload, completion: @escaping (MMLiveChatThread?, (any Error)?) -> Void) {
        chatHandler.createThread(payload, completion: completion)
    }

    func showThreadsList(completion: @escaping ((any Error)?) -> Void) {
        chatHandler.showThreadsList(completion: completion)
    }

    func openNewThread(completion: @escaping ((any Error)?) -> Void) {
        chatHandler.openNewThread(completion: completion)
    }

    func sendContextualData(_ metadata: String, multiThreadStrategy: MMChatMultiThreadStrategy, completion: @escaping ((any Error)?) -> Void) {
        chatHandler.sendContextualData(metadata, multiThreadStrategy: multiThreadStrategy, completion: completion)
    }
    
    func setWidgetTheme(_ themeName: String, completion: @escaping ((any Error)?) -> Void) {
        chatHandler.setWidgetTheme(themeName, completion: completion)
    }
    
    func getThreads(completion: @escaping (Swift.Result<[MMLiveChatThread], Error>) -> Void) {
        chatHandler.getThreads(completion: completion)
    }
    
    func openThread(with id: String, completion: @escaping (Swift.Result<MMLiveChatThread, any Error>) -> Void) {
        chatHandler.openThread(with: id, completion: completion)
    }
    
    func getActiveThread(completion: @escaping (Swift.Result<MMLiveChatThread?, any Error>) -> Void) {
        chatHandler.getActiveThread(completion: completion)
    }
    
    func reset() {
        chatHandler.reset()
    }
     
    // MARK: - Utility methods

    private func didLoadWidget(with error: Error?) {
        guard let error = error else { return } // we want to propagate errors only. Successful widget loads require the proper view state update
        chatHandler.triggerPendingActions(with: error)
    }

    internal func sendCachedContextData() {
        guard let contextualData = MMInAppChatService.sharedInstance?.contextualData else {
            return
        }
        
        MMInAppChatService.sharedInstance?.contextualData = nil
        self.sendContextualData(contextualData.metadata, multiThreadStrategy: contextualData.multiThreadStrategy, completion: { _ in })
    }
    
    private func onError(errors: ChatErrors) {
        let exception = MMChatException(code: errors.rawValue, name: errors.rawDescription, message: errors.localizedDescription, retryable: true)
        self.delegate?.didReceiveError(exception: exception)
        
        if self.chatHandler.pendingActions.count > 0 {
            didLoadWidget(with: exception)
        }
    }
}

extension MMInAppChatWidgetAPI: WidgetSubscriber {
    func didLoadWidget(_ widget: ChatWidget) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            chatHandler.chatWidget = widget
            chatHandler.webView.isSettingLanguage = false // API doesn't show language changes in UI, so we avoid unnecessary reloads. These reloads may cause issues on identify if another widget is being loaded in parallel (ie, API use, and also in a view controller)
            chatHandler.webView.loadWidget(widget)
        }
    }

    func didReceiveError(_ errors: ChatErrors) {
        if errors == .configurationSyncError {
            onError(errors: errors)
        }
    }
}

extension MMInAppChatWidgetAPI: WebEventHandlerProtocol {
    func onEvent(type: JSMessageType, jsMessage: any JSMessage) {
        switch type {
        case .enableControls:
            guard let jsMessage = jsMessage as? EnableControlsJSMessage else {
                logError(failureDescription(for: jsMessage, type: type))
                return
            }
            chatHandler.webView.isLoaded = jsMessage.enabled
        case .onError:
            guard let jsMessage = jsMessage as? ErrorJSMessage else {
                logError(failureDescription(for: jsMessage, type: type))
                return
            }
            
            var chatError = ChatErrors.jsError
            chatError.rawDescription = jsMessage.message
            onError(errors: chatError)
        case .onViewChanged:
            guard let jsMessage = jsMessage as? ViewStateJSMessage else {
                logError(failureDescription(for: jsMessage, type: type))
                return
            }

            let state = jsMessage.state
            if chatHandler.currentViewState != state, state != .loading {
                // In case actions are pending, we finally trigger them successfully if the view state just became valid.
                chatHandler.triggerPendingActions(with: nil)
                addMessageEventListener()
            }
            chatHandler.currentViewState = state

            if state != .loading && state != .loadingThread && state != .unknown {
                sendCachedContextData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: { [weak self] in /// Thread methods require some delay, even If it's loaded
                    self?.didLoadWidget(with: nil)
                })
            }
            
            delegate?.didChangeState(to: state)

        case .onMessageEvent:
            guard let jsMessage = jsMessage as? OnMessageReceivedJSMessage else {
                logError(failureDescription(for: jsMessage, type: type))
                return
            }
            delegate?.onRawMessageReceived(jsMessage.message)
        default: return
        }
    }

    private func addMessageEventListener() {
        if !didSetOnMessageReceivedListener { // we cannot add listeners before widget achieves a post-loading state
            chatHandler.webView.addMessageReceivedListener(completion: { [weak self] error in
                if let error = error {
                    self?.logError(error.description)
                }
                self?.didSetOnMessageReceivedListener = true
                return
            })
        }
    }
}

extension MMInAppChatWidgetAPI: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !chatHandler.webView.isReset else {
            chatHandler.webView.isReset = false
            return
        }
        webView.addViewChangedListener(completion: { [weak self] error in
            if let error = error {
                self?.logError(error.description)
            }
            return
        })
    }
}
