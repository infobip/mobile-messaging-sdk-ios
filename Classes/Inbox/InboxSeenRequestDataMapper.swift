// 
//  InboxSeenRequestDataMapper.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class InboxSeenRequestDataMapper {
    static func requestBody(messageIds: [String], externalUserId: String, seenDate: Date) -> RequestBody {
        return [
            MMConsts.APIKeys.seenExternalUserId: externalUserId,
            MMConsts.APIKeys.seenMessages: messageIds.compactMap({ (id) -> DictionaryRepresentation?  in
            
            return [
                MMConsts.APIKeys.messageId: id,
                MMConsts.APIKeys.seenTimestampDelta: seenDate.timestampDelta,
                MMConsts.APIKeys.seenMessageInbox: true
            ]
        })]
    }
}
