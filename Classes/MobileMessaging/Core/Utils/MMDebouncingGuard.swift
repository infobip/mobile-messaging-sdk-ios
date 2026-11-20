//
//  MMDebouncingGuard.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

/// Drops a call when the same operation type with equal data was admitted less than `window` seconds ago
/// (or, once it succeeded, completed successfully less than `window` seconds ago). iOS port of Android's
/// `DebouncingGuard`, with these additions:
/// - writes (`requiresSuccessToDrop`) are only dropped after an identical write *succeeded*, so a dropped
///   write never reports success for a change that was not saved;
/// - every admitted call gets a `Ticket` and must `finish(_:succeeded:)`; a failure frees the entry for an
///   immediate retry. A stale ticket (its entry replaced by a newer call) never touches the newer entry;
/// - `invalidate(after:except:)` clears entries a change of the user made non-equivalent (`Change`).
///
/// Internal to the SDK, invisible to integrators.
final class MMDebouncingGuard: NamedLogger {
    enum OperationType: String, CaseIterable {
        case userSessionReport
        case personalize
        case depersonalizeInstallation
        case saveUser
        case fetchUser
    }

    /// A change of the user after which earlier identical calls of `affectedTypes` are no longer equivalent
    /// to new ones. Writes report it when queued (covers calls made while they are pending) and again when
    /// they succeed (covers results cached meanwhile by calls that overtook them on the queue).
    enum Change {
        /// User data changed: written to the server (save, foreground/startup sync) or only locally (`persistUser`).
        case userData
        /// The installation was personalized.
        case personalization
        /// A fetched user replaced local data.
        case fetchedUser
        /// The primary device of the user changed.
        case primaryDevice
        /// Installation data changed (`saveInstallation`, `persistInstallation`, an installation sync or applied fetch).
        case installationData
        /// The user was depersonalized (logout).
        case logout

        var affectedTypes: [OperationType] {
            switch self {
            // .depersonalizeInstallation also holds the logout entry: changed user data makes a logout necessary again
            case .userData: return [.saveUser, .personalize, .fetchUser, .depersonalizeInstallation]
            case .personalization, .fetchedUser: return [.saveUser, .personalize, .fetchUser, .depersonalizeInstallation]
            // .depersonalizeInstallation also holds the logout entry: a logout resets the primary flag again
            case .primaryDevice: return [.personalize, .fetchUser, .depersonalizeInstallation]
            // the installation (e.g. its primary flag) is part of what personalize(setDeviceAsPrimary) and the
            // fetched user's installation list describe
            case .installationData: return [.depersonalizeInstallation, .personalize, .fetchUser]
            case .logout: return OperationType.allCases
            }
        }
    }

    /// Identifies one admitted call.
    struct Ticket: Hashable {
        let type: OperationType
        fileprivate let id: UInt64
    }

    static let defaultWindow: TimeInterval = 1.0

    /// Writes: a dropped call is answered with success, which is only true once an identical write succeeded.
    static func requiresSuccessToDrop(_ type: OperationType) -> Bool {
        switch type {
        case .saveUser, .personalize, .depersonalizeInstallation: return true
        case .fetchUser, .userSessionReport: return false
        }
    }

    private struct Entry {
        var timestamp: Date
        let key: Data?
        var succeeded: Bool
        let id: UInt64
    }

    let window: TimeInterval
    private var entries: [OperationType: Entry] = [:]
    private var lastId: UInt64 = 0
    private let lock = NSLock()

    init(window: TimeInterval = MMDebouncingGuard.defaultWindow) {
        self.window = window
    }

    /// Returns a ticket when the call should proceed, `nil` when it is a duplicate within the window.
    func admit(_ type: OperationType, data: [String: Any]?) -> Ticket? {
        let key = MMDebouncingGuard.canonicalKey(data)
        return locked {
            let now = MobileMessaging.date.now
            if isDuplicateLocked(type, key: key, now: now) {
                logDebug("\(type.rawValue) dropped: identical call within \(window)s")
                return nil
            }
            lastId &+= 1
            entries[type] = Entry(timestamp: now, key: key, succeeded: false, id: lastId)
            return Ticket(type: type, id: lastId)
        }
    }

    /// Whether `admit` would drop this call now. Records nothing, so it never replaces the entry of a call that
    /// is still in flight.
    func isDuplicate(_ type: OperationType, data: [String: Any]?) -> Bool {
        let key = MMDebouncingGuard.canonicalKey(data)
        return locked { isDuplicateLocked(type, key: key, now: MobileMessaging.date.now) }
    }

    private func isDuplicateLocked(_ type: OperationType, key: Data?, now: Date) -> Bool {
        guard let previous = entries[type], previous.key == key,
              previous.succeeded || !MMDebouncingGuard.requiresSuccessToDrop(type) else { return false }
        let elapsed = now.timeIntervalSince(previous.timestamp)
        // negative elapsed means the clock went backwards; never drop in that case
        return elapsed >= 0 && elapsed < window
    }

    /// For checks whose outcome is not reported back.
    func shouldAllow(_ type: OperationType, data: [String: Any]?) -> Bool {
        return admit(type, data: data) != nil
    }

    /// Reports the outcome of an admitted call. A success restarts the window from now, so identical calls
    /// within `window` after the *successful completion* are duplicates however long the request took; any
    /// other outcome clears the entry so a retry is sent. No-op if a newer call has replaced the entry.
    func finish(_ ticket: Ticket, succeeded: Bool) {
        locked {
            guard var entry = entries[ticket.type], entry.id == ticket.id else { return }
            if succeeded {
                entry.timestamp = MobileMessaging.date.now
                entry.succeeded = true
                entries[ticket.type] = entry
            } else {
                entries[ticket.type] = nil
            }
        }
    }

    func succeeded(_ ticket: Ticket) {
        finish(ticket, succeeded: true)
    }

    func release(_ ticket: Ticket) {
        finish(ticket, succeeded: false)
    }

    /// Clears the entries `change` made non-equivalent, except the one of the caller's own type `kept`.
    func invalidate(after change: Change, except kept: OperationType? = nil) {
        invalidate(change.affectedTypes.filter { $0 != kept })
    }

    func invalidate(_ types: [OperationType] = OperationType.allCases) {
        locked { types.forEach { entries[$0] = nil } }
    }

    func resetAll() {
        invalidate()
    }

    /// Bytes of the JSON serialization with sorted keys, i.e. what goes over the wire. Compared byte by byte:
    /// unlike NSDictionary equality it keeps `true` vs `1` apart, and unlike `String` equality it does not treat
    /// Unicode canonically equivalent text (precomposed "é" vs "e" + combining accent) as the same.
    /// Data that cannot be serialized gets a unique key, so such a call is never treated as a duplicate.
    static func canonicalKey(_ data: [String: Any]?) -> Data? {
        guard let data = data else { return nil }
        guard JSONSerialization.isValidJSONObject(data),
              let json = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys]) else {
            return Data(("unserializable-" + UUID().uuidString).utf8)
        }
        return json
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}
