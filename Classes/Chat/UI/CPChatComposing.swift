// 
//  CPChatComposing.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UIKit

//MARK: Compose bar
public protocol MMComposeBarDelegate: UITextViewDelegate {
    @available(*, deprecated, message: "Method 'send' needs to be used instead. This method will be removed in a future release")
    func sendText(_ text: String, completion: @escaping (_ error: NSError?) -> Void)
    @available(*, deprecated, message: "Method 'send' needs to be used instead. This method will be removed in a future release")
    func sendAttachment(_ fileName: String?, data: Data, completion: @escaping (_ error: NSError?) -> Void)
    @available(*, deprecated, message: "Method 'send' needs to be used instead. This method will be removed in a future release")
    func sendDraft(_ message: String?, completion: @escaping (_ error: NSError?) -> Void)
    func send(_ payload: MMLivechatPayload, completion: @escaping (_ error: NSError?) -> Void)
    func send(_ payload: MMLivechatPayload) async throws
    func textDidChange(_ text: String?, completion: @escaping (_ error: NSError?) -> Void)
    func textDidChange(_ text: String?) async throws
    func attachmentButtonTapped()
    func composeBarWillChangeFrom(_ startFrame: CGRect, to endFrame: CGRect,
                                       duration: TimeInterval, animationCurve: UIView.AnimationCurve)
    func composeBarDidChangeFrom(_ startFrame: CGRect, to endFrame: CGRect)
}

public protocol MMChatComposer: UIView {
    var delegate: MMComposeBarDelegate? { set get }
}

public extension MMComposeBarDelegate {
    func send(_ payload: MMLivechatPayload) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            send(payload) { error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }

    func textDidChange(_ text: String?) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            textDidChange(text) { error in
                if let error = error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
}
