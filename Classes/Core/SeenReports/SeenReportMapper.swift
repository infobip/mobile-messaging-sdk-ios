//
//  SeenReportMapper.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01.02.2020.
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
