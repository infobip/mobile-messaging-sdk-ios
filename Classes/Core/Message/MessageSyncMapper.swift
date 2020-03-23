//
//  MessageSyncMapper.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01.02.2020.
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
