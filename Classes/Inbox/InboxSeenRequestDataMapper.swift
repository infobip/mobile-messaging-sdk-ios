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
            Consts.APIKeys.seenExternalUserId: externalUserId,
            Consts.APIKeys.seenMessages: messageIds.compactMap({ (id) -> DictionaryRepresentation?  in
            
            return [
                Consts.APIKeys.messageId: id,
                Consts.APIKeys.seenTimestampDelta: seenDate.timestampDelta,
                Consts.APIKeys.seenMessageInbox: true
            ]
        })]
    }
}
