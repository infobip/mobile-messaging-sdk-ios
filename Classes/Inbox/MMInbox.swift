//
//  MMInbox.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 25.02.2022.
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
     Array of inbox messages ordered by message send date-time.
     */
    public var messages: [MM_MTMessage]
    public init?(json value: JSON) {
        self.messages = value[MMConsts.InboxKeys.messages].arrayValue.compactMap { MM_MTMessage(messageSyncResponseJson: $0) }
        self.countTotal = value[MMConsts.InboxKeys.countTotal].intValue
        self.countUnread = value[MMConsts.InboxKeys.countUnread].intValue
    }
}
