// 
//  MMInbox.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

typealias FetchInboxResult = MMResult<MMInbox>

class GetInbox: GetRequest {
    typealias ResponseType = MMInbox
    
    init(applicationCode: String, accessToken: String?, externalUserId: String, from: Date?, to: Date?, limit: Int?, topic: String?) {
        var parameters: [String: String] = [:]
        
        parameters[MMConsts.InboxKeys.messageTopic] = topic
        parameters[MMConsts.InboxKeys.dateTimeFrom] = (from?.mm_epochUnixTimestamp() as Int64?).flatMap { String($0) }
        parameters[MMConsts.InboxKeys.dateTimeTo] = (to?.mm_epochUnixTimestamp() as Int64?).flatMap { String($0) }
        parameters[MMConsts.InboxKeys.limit] = limit.flatMap{ String($0) }
        
        super.init(applicationCode: applicationCode, path: .Inbox, pushRegistrationId: nil, body: nil, parameters: parameters as RequestParameters, pathParameters: ["{externalUserId}": externalUserId], accessToken: accessToken)
    }
}

/**
 The class encapsulates user inbox data.
 */
@objcMembers public final class MMInbox: NSObject, JSONDecodable {
    /**
     Total number of messages available in the Inbox. Maximum is limited to 100 messages.
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
    public init?(json value: JSON) {
        self.messages = value[MMConsts.InboxKeys.messages].arrayValue.compactMap { MM_MTMessage(messageSyncResponseJson: $0) }
        self.countTotal = value[MMConsts.InboxKeys.countTotal].intValue
        self.countUnread = value[MMConsts.InboxKeys.countUnread].intValue
        self.countTotalFiltered = MMInbox.extractOptionalInt(from: value, key: MMConsts.InboxKeys.countTotalFiltered)
        self.countUnreadFiltered = MMInbox.extractOptionalInt(from: value, key: MMConsts.InboxKeys.countUnreadFiltered)
        super.init()
    }
    
    public init(messages: [MM_MTMessage], countTotal: Int, countUnread: Int, countTotalFiltered: Int?, countUnreadFiltered: Int?) {
        self.messages = messages
        self.countTotal = countTotal
        self.countUnread = countUnread
        self.countTotalFiltered = countTotalFiltered
        self.countUnreadFiltered = countUnreadFiltered
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
