// 
//  MMInboxService.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

public class MMInboxService: MobileMessagingService {
    private let q: DispatchQueue
    static var sharedInstance: MMInboxService?
    private var seenMessageIds: Set<String>
    private var seenQueue: DispatchQueue
    
    init(mmContext: MobileMessaging) {
        self.q = DispatchQueue(label: "inbox-service", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        self.seenMessageIds = Set()
        self.seenQueue = DispatchQueue(label: "inbox-service-seen-messages-queue")
        super.init(mmContext: mmContext, uniqueIdentifier: "MMInboxService")
    }
    
    /**
     Asynchronously fetches inbox data for authorised user. Uses access token (JWT in a strictly predefined format) for authorization.
     Completion-handler form of `fetchInbox(token:externalUserId:options:) async`; see it for validation, registration and error details. The completion is called on the main queue.
     - parameter token: Access token (JWT in a strictly predefined format) required for current user to have access to the Inbox messages.
     - parameter externalUserId: External User ID is meant to be an ID of a user in an external (non-Infobip) service.
     - parameter options: Filtering options applied to messages list in response.
     - parameter completion: The block to execute on the main queue after the operation completes.
     - parameter inbox: Inbox object containing list of messages and message counters.
     - parameter error: Optional error.
     */
    @objc public func fetchInbox(token: String, externalUserId: String, options: MMInboxFilterOptions?, completion: @escaping (_ inbox: MMInbox?, _ error: NSError?) -> Void) {
        complete(completion) { try await self.fetchInbox(token: token, externalUserId: externalUserId, options: options) }
    }
    
    
    /**
     Asynchronously fetches inbox data for authorised user. Uses Application Code for authorization.
     Completion-handler form of `fetchInbox(externalUserId:options:) async`; see it for validation, registration and error details. The completion is called on the main queue.
     - Attention: This version of API uses Application Code (or API key) based authorization. This is not the most secure way of authorization because it is heavily dependent on how secure is your Application Code stored on a device. If it's hardcoded, consider obfuscating the Application Code string (we can recommend the following open-source library for string obfuscation: [UAObfuscatedString](https://github.com/UrbanApps/UAObfuscatedString)).
     - Remark: If the security is a crucial aspect, consider using the alternative `fetchInbox` API that is based on access token authorization:
    ```
    func fetchInbox(token: String,
                    externalUserId: String,
                    options: MMInboxFilterOptions?,
                    completion: @escaping (_ inbox: MMInbox?, _ error: NSError?) -> Void)
    ```
     
     
     - parameter externalUserId: External User ID is meant to be an ID of a user in an external (non-Infobip) service.
     - parameter options: Filtering options applied to messages list in response.
     - parameter completion: The block to execute on the main queue after the operation completes.
     - parameter inbox: Inbox object containing list of messages and message counters.
     - parameter error: Optional error.
     */
    @objc public func fetchInbox(externalUserId: String, options: MMInboxFilterOptions?, completion: @escaping (_ inbox: MMInbox?, _ error: NSError?) -> Void) {
        complete(completion) { try await self.fetchInbox(externalUserId: externalUserId, options: options) }
    }
    
    
    /**
     Asynchronously marks inbox message as seen.
     Completion-handler form of `setSeen(externalUserId:messageIds:) async`. The completion is called on the main queue.
     
     - parameter externalUserId: External User ID is meant to be an ID of a user in an external (non-Infobip) service.
     - parameter messageIds: Array of inbox messages identifiers that need to be marked as seen.
     - parameter completion: The block to execute on the main queue after the operation completes.
     - parameter error: Optional error.
     */
    @objc public func setSeen(externalUserId: String, messageIds: [String], completion: @escaping (_ error: NSError?) -> Void) {
        // Reserved at call time, so consecutive calls never send the same message twice.
        let unseenMessageIds = reserveUnseen(messageIds)
        complete(completion) { try await self.sendSeen(unseenMessageIds, externalUserId: externalUserId) }
    }
    
    public override var systemData: [String: AnyHashable]? {
        return ["inbox": true]
    }
    
    private static let multipleTopicsFetchLimit = 1000
    
    private func doFetchInbox(token: String?, externalUserId: String, options: MMInboxFilterOptions?) async throws -> MMInbox? {
        if let description = identityValidationError(token: token, externalUserId: externalUserId) {
            throw validationError(description)
        }
        if options?.topics?.isEmpty == false, options?.cursor != nil {
            throw validationError("Cursor pagination is not supported with a nonempty topics array; use the singular topic option instead.")
        }
        guard hasRegistration else {
            throw NSError(type: .NoRegistration)
        }
        guard let topics = options?.topics, !topics.isEmpty else {
            return try await getInbox(token: token, externalUserId: externalUserId, from: options?.fromDateTime, to: options?.toDateTime,
                                      limit: options?.limit, topic: options?.topic, cursor: options?.cursor)
        }
        // For multiple topics, fetch up to 1000 messages without a server-side topic filter and filter client-side
        guard let serverInbox = try await getInbox(token: token, externalUserId: externalUserId, from: options?.fromDateTime, to: options?.toDateTime,
                                                   limit: Self.multipleTopicsFetchLimit, topic: nil, cursor: nil) else {
            return nil
        }
        let filteredMessages = serverInbox.messages.filter { message in
            guard let messageTopic = message.topic else {
                return false
            }
            return topics.contains(messageTopic)
        }
        
        let limitedMessages: [MM_MTMessage]
        if let limit = options?.limit, limit > 0 && filteredMessages.count > limit {
            limitedMessages = Array(filteredMessages.prefix(limit))
        } else {
            limitedMessages = filteredMessages
        }
        
        return MMInbox(
            messages: limitedMessages,
            countTotal: serverInbox.countTotal,
            countUnread: serverInbox.countUnread,
            countTotalFiltered: filteredMessages.count,
            countUnreadFiltered: filteredMessages.filter { $0.seenStatus == .NotSeen }.count
        )
    }
    
    /// Bridges the callback-based networking layer.
    private func getInbox(token: String?, externalUserId: String, from: Date?, to: Date?, limit: Int?, topic: String?, cursor: String?) async throws -> MMInbox? {
        try await withCheckedThrowingContinuation { continuation in
            mmContext.remoteApiProvider.getInbox(
                applicationCode: mmContext.applicationCode,
                accessToken: token,
                externalUserId: externalUserId,
                from: from,
                to: to,
                limit: limit,
                topic: topic,
                cursor: cursor,
                queue: q) { result in
                    if let error = result.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: result.value)
                    }
                }
        }
    }
    
    private func doDeleteMessages(token: String?, externalUserId: String, messageIds: [String]) async throws {
        if let description = identityValidationError(token: token, externalUserId: externalUserId) {
            throw validationError(description)
        }
        guard !messageIds.isEmpty else {
            throw validationError("At least one message identifier is required.")
        }
        guard !messageIds.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw validationError("Message identifiers must not be blank.")
        }
        guard hasRegistration else {
            throw NSError(type: .NoRegistration)
        }

        // Bridges the callback-based networking layer.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            mmContext.remoteApiProvider.deleteInboxMessages(
                applicationCode: mmContext.applicationCode,
                accessToken: token,
                externalUserId: externalUserId,
                messageIds: messageIds,
                queue: q) { result in
                    if let error = result.error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
        }
    }
    
    /// Returns the messages not yet marked as seen by this service and marks them as pending.
    private func reserveUnseen(_ messageIds: [String]) -> [String] {
        seenQueue.sync {
            let unseen = messageIds.filter { !seenMessageIds.contains($0) }
            seenMessageIds.formUnion(unseen)
            return unseen
        }
    }
    
    /// Sends the seen status for reserved messages. On failure they are released, so a retry sends them again.
    private func sendSeen(_ messageIds: [String], externalUserId: String) async throws {
        guard !messageIds.isEmpty else {
            return
        }
        let body = InboxSeenRequestDataMapper.requestBody(messageIds: messageIds, externalUserId: externalUserId, seenDate: MobileMessaging.date.now)
        do {
            // Bridges the callback-based networking layer.
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                mmContext.remoteApiProvider.sendSeenStatus(
                    applicationCode: mmContext.applicationCode,
                    pushRegistrationId: mmContext.currentInstallation().pushRegistrationId,
                    body: body,
                    queue: q) { result in
                        if let error = result.error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
            }
        } catch {
            seenQueue.sync { seenMessageIds.subtract(messageIds) }
            throw error
        }
    }
    
    private var hasRegistration: Bool {
        return mmContext.currentInstallation().pushRegistrationId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func identityValidationError(token: String?, externalUserId: String) -> String? {
        if let token = token, token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "JWT token must not be blank."
        }
        if externalUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "External user ID must not be blank."
        }
        return nil
    }

    /// `mm_code` of local validation errors. Same as Android's `INBOX_INVALID_PARAMETERS`, so plugins report identical errors on both platforms.
    static let invalidParametersErrorCode = "20013"

    private func validationError(_ description: String) -> NSError {
        let error = NSError(type: .UserDataValidationError, description: description)
        var userInfo = error.userInfo
        userInfo[NSLocalizedDescriptionKey] = description
        // `mm_code` reads the server error `messageId` key.
        userInfo[MMConsts.APIKeys.messageId] = MMInboxService.invalidParametersErrorCode
        return NSError(domain: error.domain, code: error.code, userInfo: userInfo)
    }
    
    /// Runs an async operation for a completion-handler API and calls `completion` on the main queue.
    private func complete(_ completion: @escaping (NSError?) -> Void, _ operation: @escaping () async throws -> Void) {
        complete({ (_: Void?, error) in completion(error) }, operation)
    }
    
    /// Runs an async operation for a completion-handler API and calls `completion` on the main queue.
    private func complete<Value>(_ completion: @escaping (Value?, NSError?) -> Void, _ operation: @escaping () async throws -> Value?) {
        Task { @MainActor in
            do {
                completion(try await operation(), nil)
            } catch {
                completion(nil, error as NSError)
            }
        }
    }
    
    public override func stopService(_ completion: @escaping (Bool) -> Void) {
        super.stopService(completion)
        self.seenMessageIds.removeAll()
        MMInboxService.sharedInstance = nil
    }
}

// MARK: - Async/Await APIs
// Primary inbox APIs. The fetch and seen completion-handler APIs above wrap them; delete has no completion-handler variant.

extension MMInboxService {

    /**
     Fetches inbox data for authorised user. Uses access token (JWT in a strictly predefined format) for authorization.
     Blank tokens or external user IDs are rejected locally. A blank token never falls back to Application Code authorization.
     Requires a nonblank push registration ID. Before registration completes, throws `MMInternalErrorType.NoRegistration` without sending a request; retry after `MMNotificationRegistrationUpdated`.
     - parameter token: Access token (JWT in a strictly predefined format) required for current user to have access to the Inbox messages.
     - parameter externalUserId: External User ID is meant to be an ID of a user in an external (non-Infobip) service.
     - parameter options: Filtering options applied to messages list in response.
     - returns: Inbox object containing list of messages and message counters.
     - throws: NSError if the operation fails. Local validation errors have `MMInternalErrorDomain` domain and `mm_code` "20013"; server errors carry the server error code in `mm_code` when the server provided one.
     */
    public func fetchInbox(token: String, externalUserId: String, options: MMInboxFilterOptions?) async throws -> MMInbox? {
        try await doFetchInbox(token: token, externalUserId: externalUserId, options: options)
    }

    /**
     Fetches inbox data for authorised user. Uses Application Code for authorization.
     Blank external user IDs are rejected locally.
     Requires a nonblank push registration ID. Before registration completes, throws `MMInternalErrorType.NoRegistration` without sending a request; retry after `MMNotificationRegistrationUpdated`.
     - Attention: This version of API uses Application Code (or API key) based authorization. This is not the most secure way of authorization because it is heavily dependent on how secure is your Application Code stored on a device.
     - parameter externalUserId: External User ID is meant to be an ID of a user in an external (non-Infobip) service.
     - parameter options: Filtering options applied to messages list in response.
     - returns: Inbox object containing list of messages and message counters.
     - throws: NSError if the operation fails.
     */
    public func fetchInbox(externalUserId: String, options: MMInboxFilterOptions?) async throws -> MMInbox? {
        try await doFetchInbox(token: nil, externalUserId: externalUserId, options: options)
    }

    /**
     Marks inbox messages as seen.
     Messages already marked as seen by this service, or currently being marked, are not sent again. If the request fails, they can be marked again.
     - parameter externalUserId: External User ID is meant to be an ID of a user in an external (non-Infobip) service.
     - parameter messageIds: Array of inbox messages identifiers that need to be marked as seen.
     - throws: NSError if the operation fails.
     */
    public func setSeen(externalUserId: String, messageIds: [String]) async throws {
        try await sendSeen(reserveUnseen(messageIds), externalUserId: externalUserId)
    }

    /**
     Deletes inbox messages of authorised user. Uses access token (JWT in a strictly predefined format) for authorization - the same token used for fetching the inbox.
     Blank tokens or external user IDs are rejected locally. A blank token never falls back to Application Code authorization.
     Requires a nonblank push registration ID. Before registration completes, throws `MMInternalErrorType.NoRegistration` without sending a request; retry after `MMNotificationRegistrationUpdated`.
     
     Deleting is idempotent: messages that are missing or already deleted are treated as successfully deleted, so a failed request can safely be retried with the same message identifiers.
     A successful result means the server accepted the deletion; a subsequent `fetchInbox` may still briefly return the deleted messages and previous counters until the deletion becomes visible everywhere (eventual consistency).
     
     Objective-C callers get `deleteMessagesWithToken:externalUserId:messageIds:completionHandler:`. Its completion handler is not called on the main queue.
     - parameter token: Access token (JWT in a strictly predefined format) required for current user to have access to the Inbox messages.
     - parameter externalUserId: External User ID is meant to be an ID of a user in an external (non-Infobip) service.
     - parameter messageIds: Array of inbox messages identifiers that need to be deleted. Must not be empty and must not contain blank identifiers, otherwise the call fails without sending a request.
     - throws: NSError if the operation fails. Local validation errors have `MMInternalErrorDomain` domain and `mm_code` "20013"; server errors carry the server error code in `mm_code` when the server provided one.
     */
    @objc public func deleteMessages(token: String, externalUserId: String, messageIds: [String]) async throws {
        try await doDeleteMessages(token: token, externalUserId: externalUserId, messageIds: messageIds)
    }

    /**
     Deletes inbox messages of authorised user. Uses Application Code for authorization.
     Blank external user IDs are rejected locally.
     Requires a nonblank push registration ID. Before registration completes, throws `MMInternalErrorType.NoRegistration` without sending a request; retry after `MMNotificationRegistrationUpdated`.
     - Attention: This version of API uses Application Code (or API key) based authorization. This is not the most secure way of authorization because it is heavily dependent on how secure is your Application Code stored on a device. If it's hardcoded, consider obfuscating the Application Code string (we can recommend the following open-source library for string obfuscation: [UAObfuscatedString](https://github.com/UrbanApps/UAObfuscatedString)).
     - Remark: If the security is a crucial aspect, consider using the alternative `deleteMessages(token:externalUserId:messageIds:)` API that is based on access token authorization.
     
     Deleting is idempotent: messages that are missing or already deleted are treated as successfully deleted, so a failed request can safely be retried with the same message identifiers.
     
     Objective-C callers get `deleteMessagesWithExternalUserId:messageIds:completionHandler:`. Its completion handler is not called on the main queue.
     - parameter externalUserId: External User ID is meant to be an ID of a user in an external (non-Infobip) service.
     - parameter messageIds: Array of inbox messages identifiers that need to be deleted. Must not be empty and must not contain blank identifiers, otherwise the call fails without sending a request.
     - throws: NSError if the operation fails.
     */
    @objc public func deleteMessages(externalUserId: String, messageIds: [String]) async throws {
        try await doDeleteMessages(token: nil, externalUserId: externalUserId, messageIds: messageIds)
    }
}
