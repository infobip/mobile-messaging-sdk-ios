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
        send(text.livechatBasicPayload, completion: completion)
    }

    public func sendAttachment(_ fileName: String?, data: Data, completion: @escaping ((any Error)?) -> Void) {
        let payload = MMLivechatBasicPayload(fileName: fileName, data: data)
        send(payload, completion: completion)
    }

    public func sendDraft(_ message: String?, completion: @escaping ((any Error)?) -> Void) {
        send((message ?? "").livechatDraftPayload, completion: completion)
    }

    public func send(_ payload: MMLivechatPayload, completion: @escaping ((any Error)?) -> Void) {
        guard let chatError = validatePayload(payload, isCreating: false) else {
            webView.send(payload, completion)
            return
        }
        completion(NSError(chatError: chatError, chatPayload: payload))
    }

    public func createThread(_ payload: MMLivechatPayload, completion: @escaping (MMLiveChatThread?, (any Error)?) -> Void) {
        guard let chatError = validatePayload(payload, isCreating: true) else {
            webView.createThread(payload, completion)
            return
        }
        completion(nil, NSError(chatError: chatError, chatPayload: payload))
    }

    private func validatePayload(_ payload: MMLivechatPayload, isCreating: Bool) -> MMChatError? {
        var chatError: MMChatError?
        if let basicPayload = payload as? MMLivechatBasicPayload {
            if !validateTextLength(size: (basicPayload.text ?? "").count) {
                MMInAppChatService.sharedInstance?.delegate?.textLengthExceeded?(ChatAttachmentUtils.DefaultMaxTextLength)
                chatError = .messageLengthExceeded(ChatAttachmentUtils.DefaultMaxTextLength)
            } else if !validateAttachmentSize(size: basicPayload.byteCount) {
                chatError = MMChatError.attachmentSizeExceeded(maxUploadAttachmentSize)
            } else if basicPayload.text?.isEmpty ?? true && basicPayload.attachment?.isEmpty ?? true {
                chatError = .wrongPayload
            }
        } else if let draftPayload = payload as? MMLivechatDraftPayload {
            if !validateTextLength(size: draftPayload.text.count) {
                MMInAppChatService.sharedInstance?.delegate?.textLengthExceeded?(ChatAttachmentUtils.DefaultMaxTextLength)
                chatError = .messageLengthExceeded(ChatAttachmentUtils.DefaultMaxTextLength)
            } else if isCreating {
                chatError = .wrongPayload // Threads cannot be created with a draft - they will not produce a conversation as result
            }
        } else if let customPayload = payload as? MMLivechatCustomPayload {
            if !validateTextLength(size: customPayload.customData.count) ||
                  !validateTextLength(size: (customPayload.agentMessage ?? "").count) ||
                  !validateTextLength(size: (customPayload.userMessage ?? "").count) {
                MMInAppChatService.sharedInstance?.delegate?.textLengthExceeded?(ChatAttachmentUtils.DefaultMaxTextLength)
                chatError = .messageLengthExceeded(ChatAttachmentUtils.DefaultMaxTextLength)
            }
        }
        return chatError
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
