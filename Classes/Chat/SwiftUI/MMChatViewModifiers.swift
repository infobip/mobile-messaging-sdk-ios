//
//  MMChatViewModifiers.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import SwiftUI

public class MMChatViewConfiguration {
    public var useExternalChatInput: Bool = false
    public var onChatStateChange: ((MMChatWebViewState) -> Void)?
    public var onBackAction: ((MMChatViewController) -> Bool)?
    public var onMakeCoordinator: ((MMChatView.Coordinator) -> Void)?
    public var composer: MMChatComposer?
    public var jwtProvider: (() -> String?)?
    public var onUnreadMessagesCountChange: ((Int) -> Void)?
    public var onChatException: ((MMChatException) -> MMChatExceptionDisplayMode)?
    public var onChatEnabled: ((Bool) -> Void)?
    public var widgetTheme: String?
    public var language: MMLanguage?

    public init() {}

    var needsDelegateInterception: Bool {
        onChatStateChange != nil ||
        jwtProvider != nil ||
        onUnreadMessagesCountChange != nil ||
        onChatException != nil ||
        onChatEnabled != nil
    }
}

// MARK: - Convenience modifiers

/// Chainable modifiers that configure the underlying `MMChatViewConfiguration`.
/// Because the configuration is a reference type, these mutate it in place and
/// return `Self`, preserving the concrete `MMChatView` type for further chaining.
public extension MMChatView {

    func useExternalChatInput(_ enabled: Bool = true) -> Self {
        configuration.useExternalChatInput = enabled
        return self
    }

    func onChatStateChange(_ handler: @escaping (MMChatWebViewState) -> Void) -> Self {
        configuration.onChatStateChange = handler
        return self
    }

    func onBackAction(_ handler: @escaping (MMChatViewController) -> Bool) -> Self {
        configuration.onBackAction = handler
        return self
    }

    func onMakeChatCoordinator(_ handler: @escaping (MMChatView.Coordinator) -> Void) -> Self {
        configuration.onMakeCoordinator = handler
        return self
    }

    func chatComposer(_ composer: MMChatComposer) -> Self {
        configuration.composer = composer
        return self
    }

    func jwtProvider(_ provider: @escaping () -> String?) -> Self {
        configuration.jwtProvider = provider
        return self
    }

    func onUnreadMessagesCountChange(_ handler: @escaping (Int) -> Void) -> Self {
        configuration.onUnreadMessagesCountChange = handler
        return self
    }

    func onChatException(_ handler: @escaping (MMChatException) -> MMChatExceptionDisplayMode) -> Self {
        configuration.onChatException = handler
        return self
    }

    func onChatEnabled(_ handler: @escaping (Bool) -> Void) -> Self {
        configuration.onChatEnabled = handler
        return self
    }

    func widgetTheme(_ themeName: String) -> Self {
        configuration.widgetTheme = themeName
        return self
    }

    func language(_ language: MMLanguage) -> Self {
        configuration.language = language
        return self
    }
}
