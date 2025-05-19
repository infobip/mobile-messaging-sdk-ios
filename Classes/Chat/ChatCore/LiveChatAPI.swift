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

class MMInAppChatWidgetAPI: NSObject, MMInAppChatWidgetAPIProtocol, NamedLogger {
    private lazy var chatHandler: ChatWebViewHandler = ChatWebViewHandler(eventHandler: self)

    private let lock = NSLock()
    private var pendingActions: [(Error?) -> Void] = []
    
    weak var delegate: MMInAppChatWidgetAPIDelegate?
    var currentViewState = MMChatWebViewState.unknown

    func loadWidget() {
        chatHandler.webView.navigationDelegate = self
        MMInAppChatService.sharedInstance?.update(for: self)
    }

    func stopConnection() {
        ensureWidgetLoaded { [weak self] error in
            guard let self else { return }
            guard let error = error else {
                chatHandler.stopConnection()
                return
            }
            
            self.logError(error.localizedDescription)
        }
    }
    
    func restartConnection() {
        ensureWidgetLoaded { [weak self] error in
            guard let self else { return }
            guard let error = error else {
                chatHandler.restartConnection()
                return
            }
            
            self.logError(error.localizedDescription)
        }
    }
    
    func setLanguage(_ language: MMLanguage, completion: @escaping ((any Error)?) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let self else { return }
            guard let error = error else {
                chatHandler.setLanguage(language, completion: completion)
                return
            }
            
            self.logError(error.localizedDescription)
        }
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
        ensureWidgetLoaded { [weak self] error in
            guard let self else { return }
            guard let error = error else {
                chatHandler.send(payload, completion: completion)
                return
            }

            self.logError(error.localizedDescription)
        }
    }

    func createThread(_ payload: any MMLivechatPayload, completion: @escaping (MMLiveChatThread?, (any Error)?) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let self else { return }
            guard let error = error else {
                chatHandler.createThread(payload, completion: completion)
                return
            }

            self.logError(error.localizedDescription)
        }
    }

    func showThreadsList(completion: @escaping ((any Error)?) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let self else { return }
            guard let error = error else {
                chatHandler.showThreadsList(completion: completion)
                return
            }
            
            self.logError(error.localizedDescription)
        }
    }
    
    func sendContextualData(_ metadata: String, multiThreadStrategy: MMChatMultiThreadStrategy, completion: @escaping ((any Error)?) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let self else { return }
            guard let error = error else {
                chatHandler.sendContextualData(metadata, multiThreadStrategy: multiThreadStrategy, completion: completion)
                return
            }
            
            self.logError(error.localizedDescription)
        }
    }
    
    func setWidgetTheme(_ themeName: String, completion: @escaping ((any Error)?) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let self else { return }
            guard let error = error else {
                chatHandler.setWidgetTheme(themeName, completion: completion)
                return
            }
            
            self.logError(error.localizedDescription)
        }
    }
    
    func getThreads(completion: @escaping (Swift.Result<[MMLiveChatThread], Error>) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let self else { return }
            guard let error = error else {
                chatHandler.getThreads(completion: completion)
                return
            }
            
            self.logError(error.localizedDescription)
        }
    }
    
    func openThread(with id: String, completion: @escaping (Swift.Result<MMLiveChatThread, any Error>) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let self else { return }
            guard let error = error else {
                chatHandler.openThread(with: id, completion: completion)
                return
            }
            
            self.logError(error.localizedDescription)
        }
    }
    
    func getActiveThread(completion: @escaping (Swift.Result<MMLiveChatThread?, any Error>) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let self else { return }
            guard let error = error else {
                chatHandler.getActiveThread(completion: completion)
                return
            }
            
            self.logError(error.localizedDescription)
        }
    }
    
    func reset() {
        pendingActions.removeAll()
        chatHandler.stopConnection()
        chatHandler.webView.load(URLRequest(url: URL(string: "about:blank")!))
        chatHandler.webView.isLoaded = false
    }
     
    // MARK: - Utility methods
    private func ensureWidgetLoaded(completion: @escaping (Error?) -> Void) {
        Thread { [weak self] in
            self?.lock.lock()

            if self?.currentViewState != .unknown, self?.currentViewState != .loading {
                completion(nil)
                self?.lock.unlock()
                return
            }

            let isFirstAction = self?.pendingActions.isEmpty ?? false
            self?.pendingActions.append(completion)

            if isFirstAction {
                DispatchQueue.mmEnsureMain {
                    self?.loadWidget()
                }
            }

            self?.lock.unlock()
        }.start()
    }
    
    private func didLoadWidget(with error: Error?) {
        guard let error = error else { return } // we want to propagate errors only. Successful widget loads require the proper view state update
        triggerPendingActions(with: error)
    }

    func triggerPendingActions(with error: Error?) {
        DispatchQueue.main.async {
            self.pendingActions.forEach { $0(error) }
            self.pendingActions.removeAll()
        }
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
        
        if self.pendingActions.count > 0 {
            didLoadWidget(with: exception)
        }
    }
}

extension MMInAppChatWidgetAPI: WidgetSubscriber {
    func didLoadWidget(_ widget: ChatWidget) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            chatHandler.chatWidget = widget
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
            if currentViewState != state, state != .loading {
                // In case actions are pending, we finally trigger them successfully if the view state just became valid.
                triggerPendingActions(with: nil)
            }
            currentViewState = state

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
}

extension MMInAppChatWidgetAPI: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.setLanguage()
        webView.addViewChangedListener(completion: { [weak self] error in
            if let error = error {
                self?.logError(error.description)
            }
            return
        })
    }
}
