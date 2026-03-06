//
//  MMChatView.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import SwiftUI

/// A SwiftUI view that presents the Infobip In-app Chat.
///
/// Basic usage:
/// ```swift
/// NavigationStack {
///     NavigationLink("Chat") {
///         MMChatView()
///     }
/// }
/// ```
///
/// With configuration:
/// ```swift
/// @State private var chatCoordinator: MMChatView.Coordinator?
/// let config = MMChatViewConfiguration()
///
/// MMChatView(configuration: config)
///     .navigationBarBackButtonHidden(true)
///     .toolbar {
///         ToolbarItem(placement: .navigationBarLeading) {
///             Button("Back") {
///                 if chatCoordinator?.handleBackAction() ?? true { dismiss() }
///             }
///         }
///     }
///     .onAppear { config.onMakeCoordinator = { chatCoordinator = $0 } }
/// ```
public struct MMChatView: UIViewControllerRepresentable {
    public typealias UIViewControllerType = MMChatViewController

    @Environment(\.dismiss) private var dismiss

    internal let configuration: MMChatViewConfiguration

    public init(configuration: MMChatViewConfiguration = MMChatViewConfiguration()) {
        self.configuration = configuration
    }

    public func makeUIViewController(context: Context) -> MMChatViewController {
        let coordinator = context.coordinator

        // Save previous global settings to restore on dismantle
        coordinator.previousNavBarAppearance = MMChatSettings.sharedInstance.shouldSetNavBarAppearance
        coordinator.previousKeyboardHandling = MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance
        coordinator.previousExternalInput = MMChatSettings.sharedInstance.shouldUseExternalChatInput
        MMChatSettings.sharedInstance.shouldSetNavBarAppearance = false
        MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance = false
        MMChatSettings.sharedInstance.shouldUseExternalChatInput = configuration.useExternalChatInput
        if let theme = configuration.widgetTheme {
            MMChatSettings.sharedInstance.widgetTheme = theme
        }
        if let language = configuration.language {
            MMLanguage.sessionLanguage = language
        }

        let chatVC: MMChatViewController
        if let composer = configuration.composer {
            chatVC = MMChatViewController.makeCustomViewController(with: composer)
        } else {
            chatVC = MMChatViewController.makeChildNavigationViewController()
        }

        coordinator.chatVC = chatVC
        coordinator.configuration = configuration
        coordinator.dismissAction = { [dismiss] in dismiss() }

        if configuration.needsDelegateInterception {
            coordinator.chatDelegate = MobileMessaging.inAppChat?.delegate
            MobileMessaging.inAppChat?.delegate = coordinator
        }

        // Defer to avoid "modifying state during view update" warning
        DispatchQueue.main.async {
            configuration.onMakeCoordinator?(coordinator)
        }

        return chatVC
    }

    public func updateUIViewController(_ uiViewController: MMChatViewController, context: Context) {
        context.coordinator.configuration = configuration
        context.coordinator.dismissAction = { [dismiss] in dismiss() }
    }

    public static func dismantleUIViewController(_ uiViewController: MMChatViewController, coordinator: Coordinator) {
        // Restore global settings
        MMChatSettings.sharedInstance.shouldSetNavBarAppearance = coordinator.previousNavBarAppearance
        MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance = coordinator.previousKeyboardHandling
        MMChatSettings.sharedInstance.shouldUseExternalChatInput = coordinator.previousExternalInput

        // Restore previous delegate
        if coordinator.chatDelegate != nil || MobileMessaging.inAppChat?.delegate === coordinator {
            MobileMessaging.inAppChat?.delegate = coordinator.chatDelegate
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    public class Coordinator: NSObject, MMInAppChatDelegate {
        /// The underlying chat view controller. Use this to send messages
        /// when using external chat input (e.g. `chatVC?.send(payload) { ... }`).
        public fileprivate(set) weak var chatVC: MMChatViewController?
        fileprivate var configuration = MMChatViewConfiguration()
        fileprivate var dismissAction: (() -> Void)?

        // State for save/restore
        fileprivate var previousNavBarAppearance: Bool = true
        fileprivate var previousKeyboardHandling: Bool = true
        fileprivate var previousExternalInput: Bool = false
        fileprivate weak var chatDelegate: MMInAppChatDelegate?

        /// Call this from a custom back button to handle multithread navigation.
        /// Returns `true` if the parent view should be dismissed, `false` if the chat handled
        /// the back action internally (e.g. navigating from thread to thread list).
        public func handleBackAction() -> Bool {
            guard let chatVC = chatVC else { return true }

            if let handler = configuration.onBackAction {
                return handler(chatVC)
            }
            return chatVC.onCustomBackPressed()
        }

        // MARK: - MMInAppChatDelegate (intercept + forward)

        public func chatDidChange(to state: MMChatWebViewState) {
            configuration.onChatStateChange?(state)
            chatDelegate?.chatDidChange?(to: state)
        }

        public func inAppChatIsEnabled(_ enabled: Bool) {
            configuration.onChatEnabled?(enabled)
            chatDelegate?.inAppChatIsEnabled?(enabled)
        }

        public func didUpdateUnreadMessagesCounter(_ count: Int) {
            configuration.onUnreadMessagesCountChange?(count)
            chatDelegate?.didUpdateUnreadMessagesCounter?(count)
        }

        public func attachmentSizeExceeded(_ maxSize: UInt) {
            chatDelegate?.attachmentSizeExceeded?(maxSize)
        }

        public func textLengthExceeded(_ maxLength: UInt) {
            chatDelegate?.textLengthExceeded?(maxLength)
        }

        public func didReceiveException(_ exception: MMChatException) -> MMChatExceptionDisplayMode {
            if let handler = configuration.onChatException {
                return handler(exception)
            }
            return chatDelegate?.didReceiveException?(exception) ?? .displayDefaultAlert
        }

        public func getJWT() -> String? {
            if let provider = configuration.jwtProvider {
                return provider()
            }
            return chatDelegate?.getJWT?()
        }
    }
}
