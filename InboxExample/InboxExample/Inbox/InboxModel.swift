//
//  InboxExample/InboxExample/Inbox/InboxModel.swift
//  InboxExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import MobileMessaging
import MobileMessagingInbox

/// Display model of an inbox message. `MM_MTMessage` is a mutable class, so SwiftUI would not notice its changes.
struct InboxMessage: Identifiable, Equatable {
    let id: String
    let title: String?
    let text: String?
    let topic: String?
    let sentAt: Date
    var isSeen: Bool
    let links: [(title: String, url: URL)]
    let customPayload: [(key: String, value: String)]

    init(_ message: MM_MTMessage) {
        id = message.messageId
        title = message.title
        text = message.text
        topic = message.topic
        sentAt = Date(timeIntervalSince1970: message.sendDateTime)
        isSeen = message.seenStatus != .NotSeen
        links = [("Deeplink", message.deeplink), ("Browser URL", message.browserUrl), ("Web view URL", message.webViewUrl), ("Content URL", message.contentUrl.flatMap(URL.init(string:)))]
            .compactMap { title, url in url.map { (title, $0) } }
        customPayload = (message.customPayload ?? [:]).map { ($0.key, "\($0.value)") }.sorted { $0.key < $1.key }
    }

    static func == (lhs: InboxMessage, rhs: InboxMessage) -> Bool {
        return lhs.id == rhs.id && lhs.isSeen == rhs.isSeen
    }
}

/// Loads, pages, marks as read and deletes the messages of one user's inbox. All SDK inbox calls of the example are here.
@MainActor
final class InboxModel: ObservableObject {
    @Published private(set) var messages: [InboxMessage] = []
    /// Counters exactly as returned by the latest response. They are never adjusted locally.
    @Published private(set) var countTotal = 0
    @Published private(set) var countUnread = 0
    /// Counters of the selected topic. Present only when the response was filtered.
    @Published private(set) var countTotalFiltered: Int?
    @Published private(set) var countUnreadFiltered: Int?
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    /// Why the last refresh or page load failed.
    @Published private(set) var errorMessage: String?

    private(set) var user: InboxUser?
    private(set) var topic: String?
    private var pageSize = 20
    @Published private var nextCursor: String?
    /// Identifies the current list. A response is applied only if the list was not reloaded for another user or topic meanwhile.
    private var listId = UUID()
    /// Messages deleted and marked as read per user. A fetch made shortly after a successful request can still return
    /// the previous state (eventual consistency), so fetched pages are corrected with these for as long as the app runs.
    private var deletedIds: [String: Set<String>] = [:]
    private var seenIds: [String: Set<String>] = [:]

    var hasMorePages: Bool {
        return nextCursor != nil
    }

    // MARK: - Loading

    /// Starts a new list for the user and topic, and loads its first page.
    func load(user: InboxUser?, topic: String?, pageSize: Int) async {
        if user != self.user || topic != self.topic || pageSize != self.pageSize {
            self.user = user
            self.topic = topic
            self.pageSize = pageSize
            // Responses still in flight for the previous user or topic are dropped.
            listId = UUID()
            nextCursor = nil
            isLoading = false
            messages = []
            hasLoaded = false
            errorMessage = nil
            countTotal = 0
            countUnread = 0
            countTotalFiltered = nil
            countUnreadFiltered = nil
        }
        await refresh()
    }

    /// Reloads the first page. Messages stay visible while loading.
    func refresh() async {
        guard let user = user else {
            return
        }
        listId = UUID()
        let listId = self.listId
        nextCursor = nil
        isLoading = true
        do {
            let inbox = try await fetch(user, limit: pageSize, cursor: nil)
            guard listId == self.listId else {
                return
            }
            messages = visible(inbox.messages, for: user)
            apply(inbox)
            errorMessage = nil
        } catch {
            guard listId == self.listId else {
                return
            }
            errorMessage = error.inboxMessage
        }
        hasLoaded = true
        isLoading = false
    }

    /// Loads the page after the last loaded one, using the cursor returned with it.
    func loadMore() async {
        guard let user = user, let cursor = nextCursor, !isLoading else {
            return
        }
        let listId = self.listId
        isLoading = true
        do {
            // The cursor is bound to the filters of the first page: the topic must stay the same. The limit may change.
            let inbox = try await fetch(user, limit: pageSize, cursor: cursor)
            guard listId == self.listId else {
                return
            }
            let loadedIds = Set(messages.map(\.id))
            messages += visible(inbox.messages, for: user).filter { !loadedIds.contains($0.id) }
            apply(inbox)
            errorMessage = nil
        } catch {
            guard listId == self.listId else {
                return
            }
            if (error as NSError).mm_code == "INVALID_CURSOR" {
                // Retrying the same cursor fails again: the list has to be loaded again from the first page.
                nextCursor = nil
            }
            errorMessage = error.inboxMessage
        }
        isLoading = false
    }

    /// Fetches the counters only (`limit: 0`), without touching loaded messages and pagination.
    private func refreshCounters() async {
        guard let user = user else {
            return
        }
        let listId = self.listId
        guard let inbox = try? await fetch(user, limit: 0, cursor: nil), listId == self.listId else {
            return
        }
        apply(inbox, updatingCursor: false)
    }

    // MARK: - Mark as read and delete

    /// Marks messages as read. `setSeen` uses the Application Code and push registration of this installation, also with JWT authorization.
    func markSeen(_ ids: [String]) async throws {
        let ids = ids.filter { id in messages.contains { $0.id == id && !$0.isSeen } }
        guard let user = user, !ids.isEmpty else {
            return
        }
        try await sdk().setSeen(externalUserId: user.externalUserId, messageIds: ids)
        seenIds[user.externalUserId, default: []].formUnion(ids)
        guard user == self.user else {
            return
        }
        for index in messages.indices where ids.contains(messages[index].id) {
            messages[index].isSeen = true
        }
        await refreshCounters()
    }

    /// Deletes messages in one request.
    func delete(_ ids: [String]) async throws {
        guard let user = user, !ids.isEmpty else {
            return
        }
        let inbox = try sdk()
        // Deleting uses the same authorization as fetching: the same JWT for the same user, or the Application Code.
        if let token = try user.token() {
            try await inbox.deleteMessages(token: token, externalUserId: user.externalUserId, messageIds: ids)
        } else {
            try await inbox.deleteMessages(externalUserId: user.externalUserId, messageIds: ids)
        }
        // Missing or already deleted IDs succeed too. Remember the deletion even if the user changed meanwhile.
        deletedIds[user.externalUserId, default: []].formUnion(ids)
        guard user == self.user else {
            return
        }
        messages.removeAll { ids.contains($0.id) }
        // Counters are taken from the server, not decremented here. They may still include the deleted messages for a moment.
        await refreshCounters()
    }

    // MARK: - Private

    private func fetch(_ user: InboxUser, limit: Int, cursor: String?) async throws -> MMInbox {
        let inbox = try sdk()
        let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: topic, limit: limit, cursor: cursor)
        let result: MMInbox?
        if let token = try user.token() {
            result = try await inbox.fetchInbox(token: token, externalUserId: user.externalUserId, options: options)
        } else {
            // Application Code authorization works for Sandbox applications only.
            result = try await inbox.fetchInbox(externalUserId: user.externalUserId, options: options)
        }
        guard let result = result else {
            throw InboxExampleError.emptyResponse
        }
        return result
    }

    private func sdk() throws -> MMInboxService {
        guard let inbox = MobileMessaging.inbox else {
            throw InboxExampleError.sdkNotStarted
        }
        return inbox
    }

    private func visible(_ messages: [MM_MTMessage], for user: InboxUser) -> [InboxMessage] {
        let deleted = deletedIds[user.externalUserId] ?? []
        let seen = seenIds[user.externalUserId] ?? []
        return messages.filter { !deleted.contains($0.messageId) }.map { message in
            var message = InboxMessage(message)
            message.isSeen = message.isSeen || seen.contains(message.id)
            return message
        }
    }

    private func apply(_ inbox: MMInbox, updatingCursor: Bool = true) {
        countTotal = inbox.countTotal
        countUnread = inbox.countUnread
        countTotalFiltered = inbox.countTotalFiltered
        countUnreadFiltered = inbox.countUnreadFiltered
        if updatingCursor {
            // `nil` when there is no further page.
            nextCursor = inbox.nextCursor
        }
    }
}

enum InboxExampleError: LocalizedError {
    case sdkNotStarted
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .sdkNotStarted: return "The SDK is not started. Enter the Application Code in Settings."
        case .emptyResponse: return "The server returned no inbox data."
        }
    }
}

extension Error {
    /// User-facing description of an inbox error. Server errors carry the error code in `mm_code`.
    var inboxMessage: String {
        let error = self as NSError
        switch error.mm_code {
        case "INVALID_CURSOR":
            return "The next page could not be loaded. Refresh the inbox."
        case "UNAUTHORIZED", "JWT_TOKEN_EXPIRED":
            // With a backend-issued JWT, request a new token and retry once.
            return "The request was not authorized. Check the Inbox authorization type and JWT key on the App Profile."
        default:
            let noRegistration = NSError(type: .NoRegistration)
            if error.domain == noRegistration.domain && error.code == noRegistration.code {
                // Fetching and deleting need the push registration of this installation.
                return "Waiting for the push registration. The inbox loads once it completes."
            }
            return error.localizedDescription
        }
    }
}
