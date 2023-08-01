//
//  InboxSeenRequestDataMapper.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 27.04.2022.
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
