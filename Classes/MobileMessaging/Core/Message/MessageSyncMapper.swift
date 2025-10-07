// 
//  MessageSyncMapper.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class MessageSyncMapper {
	static func requestBody(archiveMsgIds: [String]?, dlrMsgIds: [String]?) -> RequestBody {
		var result = RequestBody()
		result[Consts.APIKeys.archiveMsgIds] = (archiveMsgIds?.isEmpty ?? true) ? nil : archiveMsgIds
		result[Consts.APIKeys.DLRMsgIds] = (dlrMsgIds?.isEmpty ?? true) ? nil : dlrMsgIds
		return result
	}
}
