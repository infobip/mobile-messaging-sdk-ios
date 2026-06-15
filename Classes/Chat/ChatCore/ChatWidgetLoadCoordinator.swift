//
//  ChatWidgetLoadCoordinator.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

/// Ensures that only one ChatWebViewHandler loads its widget at a time, preventing
/// concurrent identify calls to the backend when multiple handlers coexist (e.g., a
/// ChatViewController and an MMInAppChatWidgetAPI instance both loading simultaneously).
actor ChatWidgetLoadCoordinator {
    static let shared = ChatWidgetLoadCoordinator()
    private init() {}

    private(set) var isLoading = false
    private var waitingContinuations: [CheckedContinuation<Void, Never>] = []
    var waitingCount: Int { waitingContinuations.count }

    func acquireLoadingSlot() async -> ChatWidgetLoadSlot {
        if !isLoading {
            isLoading = true
        } else {
            await withCheckedContinuation {
                waitingContinuations.append($0)
            }
        }
        return ChatWidgetLoadSlot()
    }

    fileprivate func releaseLoadingSlot() async {
        guard isLoading else { return }
        if let next = waitingContinuations.first {
            waitingContinuations.removeFirst()
            next.resume() // next waiter takes over; isLoading stays true
        } else {
            isLoading = false
        }
    }

    // For testing only — cancels all pending waiters and resets state.
    func resetForTesting() {
        let pending = waitingContinuations
        waitingContinuations.removeAll()
        isLoading = false
        pending.forEach { $0.resume() }
    }
}

/// Owns a ChatWidgetLoadCoordinator slot and releases it on deinit, preventing
/// leaks if a handler is deallocated while still loading.
/// Created exclusively by ChatWidgetLoadCoordinator.acquireLoadingSlot().
final class ChatWidgetLoadSlot: @unchecked Sendable {
    private let lock = NSLock()
    private var released = false

    fileprivate init() {}

    func release() {
        lock.lock()
        defer { lock.unlock() }
        guard !released else { return }
        released = true
        Task {
            await ChatWidgetLoadCoordinator.shared.releaseLoadingSlot()
        }
    }

    deinit {
        release()
    }
}
