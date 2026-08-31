// 
//  ChatExtensions.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UIKit

extension UIImage {
    convenience init?(mm_chat_named: String) {
        self.init(named: mm_chat_named, in: MMInAppChatService.resourceBundle, compatibleWith: nil)
    }
}

/// Time we are willing to wait for a single javascript evaluation in the widget before moving on.
let chatJSEvaluationTimeout: Double = 5

/// Awaits `operation` but stops waiting after `seconds`, logging `description` and returning nil on timeout.
///
/// The operation is NOT cancelled: WKWebView javascript evaluation never checks `Task.isCancelled`, so cancelling it
/// achieves nothing. We simply stop waiting on it, which is why the two racers are unstructured tasks rather than a task
/// group: a group awaits all of its children before its scope exits, so a hung evaluation would keep blocking the caller
/// well past `seconds` and defeat the whole purpose of the timeout.
///
@discardableResult
@MainActor
func withChatTimeout<T: Sendable>(
    _ description: String,
    seconds: Double = chatJSEvaluationTimeout,
    _ operation: @escaping @MainActor () async -> T
) async -> T? {
    let race = ChatTimeoutRace<T>()
    return await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
        race.continuation = continuation
        Task { @MainActor in
            race.finish(with: await operation())
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            if race.finish(with: nil) {
                MMLogError("Timed out \(description)")
            }
        }
    }
}

/// Hands the result of whichever racer finishes first to the caller, and ignores the loser.
@MainActor
private final class ChatTimeoutRace<T> {
    var continuation: CheckedContinuation<T?, Never>?

    @discardableResult
    func finish(with value: T?) -> Bool {
        guard let continuation = continuation else { return false } // the other racer already won
        self.continuation = nil
        continuation.resume(returning: value)
        return true
    }
}
