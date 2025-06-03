//
//  ChatCore.swift
//  InfobipMobileMessaging
//
//  Created by Maksym Svitlovskyi on 10/03/2025.
//

import Foundation
import WebKit

protocol ChatWebViewHandlerProtocol: MMChatWebViewActions { }

class ChatWebViewHandler: NamedLogger {
    let webView: ChatWebView
    var chatWidget: ChatWidget?
    var eventHandler: WebEventHandlerProtocol
    private let stateQueue = DispatchQueue(label: "com.infobip.ChatWebViewHandler.stateQueue")
    private var _pendingActions: [(Error?) -> Void] = []
    private var _currentViewState = MMChatWebViewState.unknown
    var pendingActions: [(Error?) -> Void] {
        get { stateQueue.sync { _pendingActions } }
        set { stateQueue.sync { _pendingActions = newValue } }
    }
    var currentViewState: MMChatWebViewState {
        get { stateQueue.sync { _currentViewState } }
        set { stateQueue.sync { _currentViewState = newValue } }
    }

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

    public func send(_ payload: any MMLivechatPayload, completion: @escaping ((any Error)?) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let chatError = self?.validatePayload(payload, isCreating: false) else {
                self?.webView.send(payload, completion)
                return
            }
            completion(NSError(chatError: chatError, chatPayload: payload))
        }
    }

    public func createThread(_ payload: any MMLivechatPayload, completion: @escaping (MMLiveChatThread?, (any Error)?) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let chatError = self?.validatePayload(payload, isCreating: true) else {
                self?.webView.createThread(payload, completion)
                return
            }
            completion(nil, NSError(chatError: chatError, chatPayload: payload))
        }
    }

    private func validateAttachment(_ basicPayload: MMLivechatBasicPayload) -> MMChatError? {
        /*
         Rules:
         - Max attachment sized checked with remote widget configuration value
         - The case of both empty (text and attachment) is invalid: we cannot create a message without payload data
         - Attachments are only allowed if their upload is enabled in the remote widget configuration
         - Attachments of extensions not in the allowed types list are to be excluded
         */
        if !validateAttachmentSize(size: basicPayload.byteCount) {
            return MMChatError.attachmentSizeExceeded(maxUploadAttachmentSize)
        } else if basicPayload.text?.isEmpty ?? true, basicPayload.attachment?.isEmpty ?? true {
            return .wrongPayload
        } else if !(basicPayload.attachment?.isEmpty ?? true), !(chatWidget?.attachments.isEnabled ?? false) {
            return .attachmentNotAllowed
        } else if let attachmentExtension = basicPayload.attachmentInfo?.fileExtension,
                  !(chatWidget?.attachments.allowedExtensions.contains(attachmentExtension) ?? false) {
            return .attachmentNotAllowed
        }
        return nil
    }

    private func validatePayload(_ payload: MMLivechatPayload, isCreating: Bool) -> MMChatError? {
        var chatError: MMChatError?
        if let basicPayload = payload as? MMLivechatBasicPayload {
            if !validateTextLength(size: (basicPayload.text ?? "").count) {
                MMInAppChatService.sharedInstance?.delegate?.textLengthExceeded?(ChatAttachmentUtils.DefaultMaxTextLength)
                chatError = .messageLengthExceeded(ChatAttachmentUtils.DefaultMaxTextLength)
            } else {
                chatError = validateAttachment(basicPayload)
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
        ensureWidgetLoaded { [weak self] error in
            guard let error = error else {
                self?.webView.sendContextualData(metadata, multiThreadStrategy: multiThreadStrategy, completion: completion)
                return
            }
            completion(error)
        }
    }

    public func getThreads(completion: @escaping (Swift.Result<[MMLiveChatThread], Error>) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let error = error else {
                self?.webView.getThreads(completion: completion)
                return
            }
            completion(.failure(error))
        }
    }

    func openThread(with id: String, completion: @escaping (Swift.Result<MMLiveChatThread, any Error>) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let error = error else {
                self?.webView.openThread(threadId: id, completion: completion)
                return
            }
            completion(.failure(error))
        }
    }

    func getActiveThread(completion: @escaping (Swift.Result<MMLiveChatThread?, any Error>) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let error = error else {
                self?.webView.getActiveThread(completion: completion)
                return
            }
            completion(.failure(error))
        }
    }

    func reset() {
        stateQueue.async { [weak self] in
            self?._pendingActions.removeAll()
            self?.stopConnection()
            DispatchQueue.main.async {
                self?.webView.isReset = true // to avoid adding js observers to a blank page
                self?.webView.load(URLRequest(url: URL(string: "about:blank")!))
                self?.webView.isLoaded = false
                self?.currentViewState = .unknown
            }
        }
    }

    func triggerPendingActions(with error: Error?) {
        stateQueue.async { [weak self] in
            guard let self = self else { return }
            let actions = self._pendingActions
            self._pendingActions.removeAll()
            DispatchQueue.main.async {
                if let error = error {
                    self.logError(error.localizedDescription)
                }
                actions.forEach { $0(error) }
            }
        }
    }

    // MARK: - Chat setup
    public func setLanguage(_ language: MMLanguage, completion: @escaping ((any Error)?) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard self?.webView.isLoaded ?? false else {
                MMLanguage.sessionLanguage = language
                completion(nil) // we ignore error in loading, as language is part of the autoconfig, to be used when webview loads
                return
            }
            self?.webView.setLanguage(language) { error in
                completion(error)
            }
        }
    }

    public func setWidgetTheme(_ themeName: String, completion: @escaping ((any Error)?) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let error = error else {
                guard self?.webView.isLoaded ?? false else {
                    completion(nil)
                    return
                }
                MMChatSettings.sharedInstance.widgetTheme = themeName
                self?.webView.setTheme(themeName, completion: completion)
                return
            }
            completion(error)
        }
    }
    // MARK: - Connection

    func stopConnection() {
        ensureWidgetLoaded { [weak self] error in
            guard error != nil else {
                self?.webView.pauseChat() { [weak self] error in
                    if let error = error {
                        self?.logError(error.description)
                    }
                }
                return
            }
        }
    }

    func restartConnection() {
        ensureWidgetLoaded { [weak self] error in
            self?.webView.resumeChat() { [weak self] error in
                if let error = error {
                    self?.logError(error.description)
                }
            }
        }
    }
    // MARK: - UI Control
    public func showThreadsList(completion: @escaping ((any Error)?) -> Void) {
        ensureWidgetLoaded { [weak self] error in
            guard let error = error else {
                self?.webView.showThreadsList(completion: completion)
                return
            }
            completion(error)
        }
    }

    // MARK: - Utility methods
    private func validateTextLength(size: Int) -> Bool {
        return size <= ChatAttachmentUtils.DefaultMaxTextLength
    }
    
    private func validateAttachmentSize(size: Int) -> Bool {
        return size <= maxUploadAttachmentSize
    }
    
    private var maxUploadAttachmentSize: UInt {
        return chatWidget?.attachments.maxSize ?? ChatAttachmentUtils.DefaultMaxAttachmentSize
    }

    func ensureWidgetLoaded(completion: @escaping (Error?) -> Void) {
        stateQueue.async { [weak self] in
            guard let self = self else { return }

            if self._currentViewState != .unknown, self._currentViewState != .loading {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let isFirstAction = self._pendingActions.isEmpty
            self._pendingActions.append(completion)

            if isFirstAction, let chatWidget = self.chatWidget {
                DispatchQueue.main.async {
                    self.webView.loadWidget(chatWidget)
                }
            }
        }
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
