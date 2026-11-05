// 
//  MMInbox.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

typealias FetchInboxResult = MMResult<MMInbox>
typealias DeleteInboxMessagesResult = MMResult<EmptyResponse>

/// External User ID is an arbitrary string (e.g. email); it must not change the route when substituted into the path.
/// Only RFC 3986 unreserved characters are left as is: the server treats `;` as the start of path parameters and drops the rest of the segment.
private func inboxPathParameters(externalUserId: String) -> [String: String] {
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    return ["{externalUserId}": externalUserId.addingPercentEncoding(withAllowedCharacters: allowed) ?? externalUserId]
}

class GetInbox: GetRequest {
    typealias ResponseType = MMInbox
    
    init(applicationCode: String, accessToken: String?, externalUserId: String, from: Date?, to: Date?, limit: Int?, topic: String?, cursor: String?) {
        var parameters: [String: String] = [:]
        
        parameters[MMConsts.InboxKeys.messageTopic] = topic
        parameters[MMConsts.InboxKeys.dateTimeFrom] = (from?.mm_epochUnixTimestamp() as Int64?).flatMap { String($0) }
        parameters[MMConsts.InboxKeys.dateTimeTo] = (to?.mm_epochUnixTimestamp() as Int64?).flatMap { String($0) }
        parameters[MMConsts.InboxKeys.limit] = limit.flatMap{ String($0) }
        parameters[MMConsts.InboxKeys.cursor] = MMInboxFilterOptions.normalizeCursor(cursor)
        
        super.init(applicationCode: applicationCode, path: .Inbox, pushRegistrationId: nil, body: nil, parameters: parameters as RequestParameters, pathParameters: inboxPathParameters(externalUserId: externalUserId), accessToken: accessToken)
    }
}

class DeleteInboxMessages: RequestData {
    typealias ResponseType = EmptyResponse
    
    init(applicationCode: String, accessToken: String?, externalUserId: String, messageIds: [String]) {
        super.init(applicationCode: applicationCode, method: .delete, path: .InboxMessages, pushRegistrationId: nil, body: nil, parameters: [MMConsts.InboxKeys.messageId: messageIds], pathParameters: inboxPathParameters(externalUserId: externalUserId), accessToken: accessToken)
    }
}

/**
 The class encapsulates user inbox data.
 */
@objcMembers public final class MMInbox: NSObject, JSONDecodable {
    /**
     Total number of messages available in the Inbox. Maximum is limited by the inbox messages limit configured for the application.
     */
    public var countTotal: Int
    
    /**
     Number of messages that not yet marked as seen/read. See `MobileMessaging.inbox.setSeen(externalUserId:messageIds:completion:)`.
     */
    public var countUnread: Int
    
    /**
     Total number of messages available in the Inbox after applying filters. Only present when filters are applied.
     */
    public var countTotalFiltered: Int?
    
    /**
     Number of unread messages after applying filters. Only present when filters are applied.
     */
    public var countUnreadFiltered: Int?
    
    /**
     Array of inbox messages ordered by message send date-time.
     */
    public var messages: [MM_MTMessage]
    
    /**
     Opaque cursor for fetching the next page of messages. Pass it as `MMInboxFilterOptions.cursor` together with the same `topic`, `fromDateTime` and `toDateTime`.
     `nil` means no further page is available from this request: either this is the last page, or pagination is not available (multiple `topics` filtering, `limit` of 0, or a backend without cursor support).
     Initializers normalize empty and whitespace-only cursors to `nil`; nonblank cursors are preserved unchanged.
     */
    public var nextCursor: String?

    /**
     Dictionary for native plugin bridges, including pagination and optional filtered counters.
     Uses the existing `MM_MTMessage.dictionaryRepresentation` format for messages.
     Absent optional values are omitted; zero counters and an empty messages array are preserved.
     */
    public var dictionaryRepresentation: DictionaryRepresentation {
        var result: DictionaryRepresentation = [
            MMConsts.InboxKeys.countTotal: countTotal,
            MMConsts.InboxKeys.countUnread: countUnread,
            MMConsts.InboxKeys.messages: messages.map { $0.dictionaryRepresentation }
        ]
        if let countTotalFiltered = countTotalFiltered {
            result[MMConsts.InboxKeys.countTotalFiltered] = countTotalFiltered
        }
        if let countUnreadFiltered = countUnreadFiltered {
            result[MMConsts.InboxKeys.countUnreadFiltered] = countUnreadFiltered
        }
        if let nextCursor = nextCursor {
            result[MMConsts.InboxKeys.nextCursor] = nextCursor
        }
        return result
    }
    
    public init?(json value: JSON) {
        self.messages = value[MMConsts.InboxKeys.messages].arrayValue.compactMap { MM_MTMessage(messageSyncResponseJson: $0) }
        self.countTotal = value[MMConsts.InboxKeys.countTotal].intValue
        self.countUnread = value[MMConsts.InboxKeys.countUnread].intValue
        self.countTotalFiltered = MMInbox.extractOptionalInt(from: value, key: MMConsts.InboxKeys.countTotalFiltered)
        self.countUnreadFiltered = MMInbox.extractOptionalInt(from: value, key: MMConsts.InboxKeys.countUnreadFiltered)
        self.nextCursor = MMInboxFilterOptions.normalizeCursor(value[MMConsts.InboxKeys.nextCursor].string)
        super.init()
    }
    
    public convenience init(messages: [MM_MTMessage], countTotal: Int, countUnread: Int, countTotalFiltered: Int?, countUnreadFiltered: Int?) {
        self.init(messages: messages, countTotal: countTotal, countUnread: countUnread, countTotalFiltered: countTotalFiltered, countUnreadFiltered: countUnreadFiltered, nextCursor: nil)
    }
    
    public init(messages: [MM_MTMessage], countTotal: Int, countUnread: Int, countTotalFiltered: Int?, countUnreadFiltered: Int?, nextCursor: String?) {
        self.messages = messages
        self.countTotal = countTotal
        self.countUnread = countUnread
        self.countTotalFiltered = countTotalFiltered
        self.countUnreadFiltered = countUnreadFiltered
        self.nextCursor = MMInboxFilterOptions.normalizeCursor(nextCursor)
        super.init()
    }
    
    private static func extractOptionalInt(from json: JSON, key: String) -> Int? {
        let jsonValue = json[key]
        // Use rawValue to access the underlying value directly
        if let intValue = jsonValue.rawValue as? Int {
            return intValue
        } else if let nsNumber = jsonValue.rawValue as? NSNumber {
            return nsNumber.intValue
        } else if let stringValue = jsonValue.string, let intValue = Int(stringValue) {
            return intValue
        } else {
            return nil
        }
    }
}
