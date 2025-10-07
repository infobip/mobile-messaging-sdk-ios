// 
//  MOSendingMapper.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class MOSendingMapper {
	static func requestBody(pushRegistrationId: String, messages: [MM_MOMessage]) -> RequestBody {
		var result = RequestBody()
		result[Consts.APIKeys.MO.from] = pushRegistrationId
		result[Consts.APIKeys.MO.messages] = messages.map { msg -> RequestBody in
			var dict = msg.dictRepresentation
			dict[Consts.APIKeys.MO.messageSentStatusCode] = nil // this attribute is redundant, the Mobile API would not expect it.
			return dict
		}
		return result
	}
}
