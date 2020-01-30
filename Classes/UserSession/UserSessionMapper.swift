//
//  UserSessionMapper.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 23.01.2020.
//

import Foundation

class UserSessionMapper {
	class func requestPayload(newSessions: [UserSessionReportObject]?, finishedSessions: [UserSessionReportObject]?) -> RequestBody {
		var ret = RequestBody()
		if let newSessions = newSessions, !newSessions.isEmpty {
			ret[Consts.UserSessions.sessionStarts] = newSessions.map { DateStaticFormatters.ISO8601SecondsFormatter.string(from: $0.startDate) }
		}
		if let finishedSessions = finishedSessions, !finishedSessions.isEmpty {
			ret[Consts.UserSessions.sessionBounds] = Dictionary(uniqueKeysWithValues: finishedSessions.map{
				(DateStaticFormatters.ISO8601SecondsFormatter.string(from:$0.startDate),
				 DateStaticFormatters.ISO8601SecondsFormatter.string(from:$0.endDate))
			})
		}
		ret["systemData"] = MobileMessaging.userAgent.systemData.requestPayload
		return ret
	}
}
