//
//  ChatWebViewHandlerProtocol.swift
//  InfobipMobileMessaging
//
//  Created by Maksym Svitlovskyi on 12/03/2025.
//

import Foundation

public protocol MMChatWebViewActions: MMLiveChatThreadsActions {

    /// Pauses the chat by closing its socket. As a result, the connection is considered terminated,
    /// and remote push notifications will be delivered to the device.
    /// This is useful when the app moves to the background or becomes inactive.
    func stopConnection()

    /// Resumes the chat by reopening its socket. As a result, the connection is reestablished,
    /// and remote push notifications will no longer be delivered to the device.
    /// - This is useful when the app moves to the foreground or becomes active.
    func restartConnection()
    
    /// Sets the language of the LiveChat widget.
    ///
    /// - Parameter language: The enum with supported languages.
    /// - Parameter completion: A closure called when the operation completes, with an optional error if it fails.
    func setLanguage(_ language: MMLanguage, completion: @escaping (Error?) -> Void)

    /// Sends draft message to be show in chat to peer's chat.
    func sendDraft(_ message: String?, completion: @escaping (Error?) -> Void)
    
    /// Sends message to the chat.
    ///
    /// - Parameter message: message to be send, max length allowed is 4096 characters
    /// - Parameter completion: A closure called when the operation completes, with an optional error if it fails.
    func sendText(_ text: String, completion: @escaping (Error?) -> Void)
    
    /// Sends attachment  to the chat.
    ///
    /// - Parameter filename: Optional attachment name
    /// - Parameter data: Attachment data
    /// - Parameter completion: A closure called when the operation completes, with an optional error if it fails.
    func sendAttachment(_ fileName: String?, data: Data, completion: @escaping (Error?) -> Void)
        
    /// Set contextual data of the Livechat Widget.
    ///
    /// - Parameter metadata: The mandatory data, sent as string, in the format of Javascript objects and values (for guidance, it must be accepted by JSON.stringify())
    /// - Parameter multiThreadStrategy:
    ///             - `ACTIVE`: Sends metadata to the current active conversation for the widget.
    ///             - `ALL`: Sends metadata to all non-closed conversations for the widget.
    ///             - `ALL_PLUS_NEW`: Sends metadata to all non-closed conversations for the widget and to any newly created conversations within the current session.
    ///
    /// - Parameter completion: A closure called when the operation completes, with an optional error if it fails.
    func sendContextualData(
        _ metadata: String,
        multiThreadStrategy: MMChatMultiThreadStrategy,
        completion: @escaping (Error?) -> Void
    )
    
    /// Set the theme of the Livechat Widget.
    ///
    /// - Parameter themeName: unique theme name defined in portal
    /// - Parameter completion: A closure called when the operation completes, with an optional error if it fails.
    func setWidgetTheme(
        _ themeName: String,
        completion: @escaping (Error?) -> Void
    )
}

public protocol MMLiveChatThreadsActions {
    /// Returns all currently available threads.
    ///
    /// - Parameter completion: A closure called when the operation completes, with a `Result<[MMLiveChatThread], Error>`.
    ///   On success, it contains an array of threads; otherwise, it contains an error.
    func getThreads(completion: @escaping (Swift.Result<[MMLiveChatThread], Error>) -> Void)

    /// Opens the thread with the specified id.
    ///
    /// - Parameter id: The thread id.
    /// - Parameter completion: A closure called when the operation completes, with a `Result<MMLiveChatThread, Error>`.
    ///   If successful, it returns the opened thread; otherwise, it returns an error.
    func openThread(with id: String, completion: @escaping (Swift.Result<MMLiveChatThread, Error>) -> Void)

    /// Returns the currently selected thread.
    ///
    /// - Parameter completion: A closure called when the operation completes, with a `Result<MMLiveChatThread?, Error>`.
    ///   It returns the current thread. If no thread is opened, it returns `nil`; otherwise, it contains an error.
    func getActiveThread(completion: @escaping (Swift.Result<MMLiveChatThread?, Error>) -> Void)

    /// Navigates to the thread list if the widget supports multiple threads.
    /// Otherwise, this function has no effect.
    ///
    /// - Parameter completion: A closure called when the operation completes, with an optional error if it fails.
    func showThreadsList(completion: @escaping (Error?) -> Void)
}
