//
//  MMChatWidgetAPIObservable.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import SwiftUI
import Combine

/// An ObservableObject that bridges `MMInAppChatWidgetAPIDelegate` callbacks
/// into SwiftUI-friendly `@Published` properties for building fully custom chat UI.
///
/// Use the `api` property directly for all chat actions (send, threads, language, etc.).
///
/// - Note: This class starts a WKWebView session immediately upon initialisation
///   (via the underlying `MMInAppChatWidgetAPI`). Ensure `MobileMessaging` has been
///   started with `.withInAppChat()` before creating an instance.
///
/// Usage:
/// ```swift
/// struct CustomChatUI: View {
///     @State private var chat: MMChatWidgetAPIObservable?
///
///     var body: some View {
///         Group {
///             if let chat {
///                 CustomChatContent(chat: chat)
///             } else {
///                 Text("Chat unavailable")
///             }
///         }
///         .onAppear {
///             if chat == nil { chat = MMChatWidgetAPIObservable() }
///         }
///     }
/// }
///
/// private struct CustomChatContent: View {
///     @ObservedObject var chat: MMChatWidgetAPIObservable
///
///     var body: some View {
///         Text("State: \(chat.viewState)")
///         Button("Send") {
///             Task { try await chat.api.send("Hello".livechatBasicPayload) }
///         }
///     }
/// }
/// ```
@MainActor
public class MMChatWidgetAPIObservable: ObservableObject {

    @Published public private(set) var viewState: MMChatWebViewState = .unknown
    @Published public private(set) var lastError: MMChatException?
    @Published public private(set) var lastRawMessage: Any?

    public private(set) var api: MMInAppChatWidgetAPIProtocol
    private var delegateProxy: DelegateProxy

    /// Creates a new observable wrapper.
    /// Returns `nil` if `MobileMessaging.inAppChat` is not available
    /// (i.e. `MobileMessaging` was not started with `.withInAppChat()`).
    public init?() {
        guard let chatService = MobileMessaging.inAppChat else {
            return nil
        }
        self.api = chatService.api
        self.delegateProxy = DelegateProxy()
        self.delegateProxy.owner = self
        self.api.delegate = self.delegateProxy
    }

    // MARK: - Delegate Proxy

    /// A non-MainActor proxy that receives delegate callbacks (potentially from any thread)
    /// and forwards them to the MainActor-isolated owner.
    class DelegateProxy: NSObject, MMInAppChatWidgetAPIDelegate {
        weak var owner: MMChatWidgetAPIObservable?

        func didReceiveError(exception: MMChatException) {
            Task { @MainActor [weak owner] in
                owner?.lastError = exception
            }
        }

        func didChangeState(to state: MMChatWebViewState) {
            Task { @MainActor [weak owner] in
                owner?.viewState = state
            }
        }

        func onRawMessageReceived(_ message: Any) {
            Task { @MainActor [weak owner] in
                owner?.lastRawMessage = message
            }
        }
    }
}
