//
//  ChatCore.swift
//  InfobipMobileMessaging
//
//  Created by Maksym Svitlovskyi on 10/03/2025.
//

import Foundation

protocol ChatWebViewHandlerProtocol: MMChatWebViewActions { }

class ChatWebViewHandler: NamedLogger {
    let webView: ChatWebView
    var chatWidget: ChatWidget?
    var eventHandler: WebEventHandlerProtocol
    
    init(webView: ChatWebView = .init(frame: .zero), eventHandler: WebEventHandlerProtocol = ChatViewEventHandler()) {
        self.webView = webView
        self.eventHandler = eventHandler
        self.webView.scriptHandler.onChatEvent = { [weak self] event, message in
            self?.eventHandler.onEvent(type: event, jsMessage: message)
        }
    }
}

extension ChatWebViewHandler: ChatWebViewHandlerProtocol {
    // MARK: - Actions
    public func sendText(_ text: String, completion: @escaping ((any Error)?) -> Void) {
        guard validateTextLength(size: text.count) else {
            MMInAppChatService.sharedInstance?.delegate?.textLengthExceeded?(ChatAttachmentUtils.DefaultMaxTextLength)
            completion(NSError(chatError: MMChatError.messageLengthExceeded(ChatAttachmentUtils.DefaultMaxTextLength)))
            return
        }
        webView.sendMessage(text, completion: completion)
    }
    
    public func sendAttachment(_ fileName: String?, data: Data, completion: @escaping ((any Error)?) -> Void) {
        guard validateAttachmentSize(size: data.count) else {
            completion(NSError(chatError: MMChatError.attachmentSizeExceeded(maxUploadAttachmentSize)))
            return
        }
        let attachment = ChatMobileAttachment(fileName, data: data)
        webView.sendMessage(attachment: attachment, completion: completion)
    }
    
    public func sendDraft(_ message: String?, completion: @escaping ((any Error)?) -> Void) {
        webView.sendDraft(message, completion: completion)
    }
    
    public func sendContextualData(_ metadata: String, multiThreadStrategy: MMChatMultiThreadStrategy, completion: @escaping ((any Error)?) -> Void) {
        webView.sendContextualData(metadata, multiThreadStrategy: multiThreadStrategy, completion: completion)
    }
    
    public func getThreads(completion: @escaping (Swift.Result<[MMLiveChatThread], Error>) -> Void) {
        webView.getThreads(completion: completion)
    }
    
    public func openThread(with id: String, completion: @escaping (Swift.Result<MMLiveChatThread, any Error>) -> Void) {
        webView.openThread(threadId: id, completion: completion)
    }
    
    func getActiveThread(completion: @escaping (Swift.Result<MMLiveChatThread?, any Error>) -> Void) {
        webView.getActiveThread(completion: completion)
    }
    // MARK: - Chat setup
    public func setLanguage(_ language: MMLanguage, completion: @escaping ((any Error)?) -> Void) {
        guard webView.isLoaded else {
            MMLanguage.sessionLanguage = language
            completion(nil)
            return
        }
        webView.setLanguage(language)
    }
    
    
    public func setWidgetTheme(_ themeName: String, completion: @escaping ((any Error)?) -> Void) {
        guard webView.isLoaded else {
            completion(nil)
            return
        }
        MMChatSettings.sharedInstance.widgetTheme = themeName
        webView.setTheme(themeName, completion: completion)
    }
    // MARK: - Connection
    public func stopConnection() {
        webView.pauseChat() { [weak self] error in
            if let error = error {
                self?.logError(error.description)
            }
        }
    }
    
    public func restartConnection() {
        webView.resumeChat() { [weak self] error in
            if let error = error {
                self?.logError(error.description)
            }
        }
    }
    // MARK: - UI Control
    public func showThreadsList(completion: @escaping ((any Error)?) -> Void) {
        webView.showThreadsList(completion: completion)
    }

    // MARK: - Utility methods
    private func validateTextLength(size: Int) -> Bool {
        return size <= ChatAttachmentUtils.DefaultMaxTextLength
    }
    
    private func validateAttachmentSize(size: Int) -> Bool {
        return size <= maxUploadAttachmentSize
    }
    
    private var maxUploadAttachmentSize: UInt {
        return chatWidget?.maxUploadContentSize ?? ChatAttachmentUtils.DefaultMaxAttachmentSize
    }
}

protocol WebEventHandlerProtocol {
    func onEvent(type: JSMessageType, jsMessage: JSMessage)
}

extension WebEventHandlerProtocol {
    func failureDescription(for jsMessage: JSMessage, type: JSMessageType) -> String {
        return "Unable to parse JSMessage \(jsMessage) on event \(type)"
    }
}


class ChatViewEventHandler: NamedLogger, WebEventHandlerProtocol {
    func onEvent(type: JSMessageType, jsMessage: JSMessage) {
        switch type {
        case .enableControls:
            guard let jsMessage = jsMessage as? EnableControlsJSMessage else {
                logError(failureDescription(for: jsMessage, type: type))
                return
            }
            MobileMessaging.inAppChat?.webViewDelegate?.didEnableControls(jsMessage.enabled)
        case .onError:
            guard let jsMessage = jsMessage as? ErrorJSMessage else {
                logError(failureDescription(for: jsMessage, type: type))
                return
            }
            MobileMessaging.inAppChat?.handleJSError(jsMessage.message)
        case .openAttachmentPreview:
            guard let jsMessage = jsMessage as? AttachmentPreviewJSMessage,
                  let attachment = ChatWebAttachment(url: jsMessage.url, typeString: jsMessage.type, fileName: jsMessage.caption) else {
                logError(failureDescription(for: jsMessage, type: type))
                return
            }
            MobileMessaging.inAppChat?.webViewDelegate?.didOpenPreview(forAttachment: attachment)
        case .setControlsVisibility:
            guard let jsMessage = jsMessage as? VisibilityControlsJSMessage else {
                logError(failureDescription(for: jsMessage, type: type))
                return
            }
            MobileMessaging.inAppChat?.webViewDelegate?.didShowComposeBar(jsMessage.isVisible)
        case .onViewChanged:
            guard let jsMessage = jsMessage as? ViewStateJSMessage else {
                logError(failureDescription(for: jsMessage, type: type))
                return
            }
            MobileMessaging.inAppChat?.webViewDelegate?.didChangeView(jsMessage.state)
        case .onMessageEvent:
            guard let jsMessage = jsMessage as? OnMessageReceivedJSMessage else {
                logError(failureDescription(for: jsMessage, type: type))
                return
            }
            MobileMessaging.inAppChat?.onRawMessageReceived?(jsMessage.message)
        }
    }
}
