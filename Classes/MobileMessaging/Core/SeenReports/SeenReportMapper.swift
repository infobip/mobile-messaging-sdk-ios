// 
//  SeenReportMapper.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class SeenReportMapper {
	static func requestBody(_ seenNotSentMessages: [MessageManagedObject]) -> RequestBody {
		return [Consts.APIKeys.seenMessages: seenNotSentMessages.compactMap({ (obj) -> DictionaryRepresentation?  in
			guard let seenDate = obj.seenDate else {
				return nil
			}
			return [
				Consts.APIKeys.messageId: obj.messageId,
				Consts.APIKeys.seenTimestampDelta: seenDate.timestampDelta
			]
		})]
	}
}
