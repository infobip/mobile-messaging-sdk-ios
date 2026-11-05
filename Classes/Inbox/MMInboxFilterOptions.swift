// 
//  MMInboxFilterOptions.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation


/**
 The class encapsulates filtering options for fetching Inbox messages from server.
 Always consider narrowing down the scope of messages that need to be fetched as it affects users traffic and networking performance.
 */
@objcMembers public class MMInboxFilterOptions: NSObject {
    public let fromDateTime: Date?
    public let toDateTime: Date?
    public let topic: String?
    public let topics: [String]?
    public let limit: Int?
    /**
     Opaque pagination cursor returned as `MMInbox.nextCursor` by the previous fetch. Nil, empty and whitespace-only cursors request the first page. Nonblank cursors are preserved unchanged.
     The cursor is only valid together with the same `topic`, `fromDateTime` and `toDateTime` used to obtain it; `limit` may change between pages.
     A nonblank cursor is not supported with any nonempty `topics` array, including a single topic. Use `topic` for server-side pagination.
     */
    public let cursor: String?
    
    
    /**
     - parameter fromDateTime: defines that messages with send datetime greater than or equal `fromDateTime` should be fetched. Default is undefined.
     - parameter toDateTime: defines that messages with send datetime less than `toDateTime` should be fetched. Default is undefined.
     - parameter topic: defines filter by topic name. Default is undefined.
     - parameter limit: defines maximum number of messages fetched within single request. Default is 20.
     */
    public convenience init(fromDateTime: Date?, toDateTime: Date?, topic: String?, limit: Int?) {
        self.init(fromDateTime: fromDateTime, toDateTime: toDateTime, topic: topic, limit: limit, cursor: nil)
    }
    
    /**
     - parameter fromDateTime: defines that messages with send datetime greater than or equal `fromDateTime` should be fetched. Default is undefined.
     - parameter toDateTime: defines that messages with send datetime less than `toDateTime` should be fetched. Default is undefined.
     - parameter topic: defines filter by topic name. Default is undefined.
     - parameter limit: defines maximum number of messages fetched within single request. Default is 20.
     - parameter cursor: `nextCursor` from the previous `MMInbox` to fetch the next page, or nil to fetch the first page. Keep `fromDateTime`, `toDateTime` and `topic` the same as for the previous page.
     */
    public init(fromDateTime: Date?, toDateTime: Date?, topic: String?, limit: Int?, cursor: String?) {
        self.fromDateTime = fromDateTime
        self.toDateTime = toDateTime
        self.topic = topic
        self.topics = nil
        self.limit = limit
        self.cursor = Self.normalizeCursor(cursor)
    }
    
    /**
     - parameter fromDateTime: defines that messages with send datetime greater than or equal `fromDateTime` should be fetched. Default is undefined.
     - parameter toDateTime: defines that messages with send datetime less than `toDateTime` should be fetched. Default is undefined.
     - parameter topics: defines filter by multiple topic names. Messages matching any of the topics will be included. When provided, filtering is done client-side after fetching all messages. Cursor pagination is not supported with multiple topics. Default is undefined.
     - parameter limit: defines maximum number of messages returned after filtering. Default is 20.
     */
    public convenience init(fromDateTime: Date?, toDateTime: Date?, topics: [String]?, limit: Int?) {
        self.init(fromDateTime: fromDateTime, toDateTime: toDateTime, topic: nil, topics: topics, limit: limit, cursor: nil)
    }
    
    private init(fromDateTime: Date?, toDateTime: Date?, topic: String?, topics: [String]?, limit: Int?, cursor: String?) {
        self.fromDateTime = fromDateTime
        self.toDateTime = toDateTime
        self.topic = topic
        self.topics = topics
        self.limit = limit
        self.cursor = Self.normalizeCursor(cursor)
    }

    /// Only blank cursors are normalized. A nonblank cursor is opaque and must not be trimmed.
    @nonobjc static func normalizeCursor(_ cursor: String?) -> String? {
        guard let cursor = cursor, !cursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return cursor
    }
    
    public required convenience init(dictRepresentation dict: DictionaryRepresentation) {
        var fromDateTime: Date?
        if let fromDateTimeValue = dict["fromDateTime"] as? String {
            fromDateTime = DateStaticFormatters.ISO8601SecondsFormatter.date(from: fromDateTimeValue)
        }
    
        var toDateTime: Date?
        if let toDateTimeValue = dict["toDateTime"] as? String {
            toDateTime = DateStaticFormatters.ISO8601SecondsFormatter.date(from: toDateTimeValue)
        }
        
        // When both are supplied, `topic` wins: it is the finer filter and supports cursor pagination. Same precedence as Android.
        if let topic = dict["topic"] as? String {
            self.init(
                fromDateTime: fromDateTime,
                toDateTime: toDateTime,
                topic: topic,
                limit: dict["limit"] as? Int,
                cursor: dict["cursor"] as? String
            )
        } else {
            self.init(
                fromDateTime: fromDateTime,
                toDateTime: toDateTime,
                topic: nil,
                topics: dict["topics"] as? [String],
                limit: dict["limit"] as? Int,
                cursor: dict["cursor"] as? String
            )
        }
    }
}
