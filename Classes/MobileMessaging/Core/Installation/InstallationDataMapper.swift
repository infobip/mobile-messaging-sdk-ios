// 
//  InstallationDataMapper.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

class InstallationDataMapper {
	class func patchRequestPayload(currentInstallation: MMInstallation, dirtyInstallation: MMInstallation, internalData: InternalData) -> RequestBody {
		let currentDict = currentInstallation.dictionaryRepresentation
		let nonReportedDict = dirtyInstallation.dictionaryRepresentation
        var ret = deltaDict(currentDict, nonReportedDict) ?? [:]
		if internalData.systemDataHash != Int64(MobileMessaging.userAgent.systemData.stableHashValue) {
			ret.merge(MobileMessaging.userAgent.systemData.requestPayload, uniquingKeysWith: { (l, r) -> Any in
				return r
			})
		}
		return adjustFieldNames(requestBody: ret)
	}

	class func postRequestPayload(dirtyInstallation: MMInstallation, internalData: InternalData) -> RequestBody {
		var ret = dirtyInstallation.dictionaryRepresentation
		ret.merge(MobileMessaging.userAgent.systemData.requestPayload, uniquingKeysWith: { (l, r) -> Any in
			return r
		})
        ret["notificationsEnabled"] = true // this is a workaround because registration may happen before user granted any permissions, so that they may be undefined. Forcing true.
		return adjustFieldNames(requestBody: ret)
	}

	class func adjustFieldNames(requestBody: RequestBody) -> RequestBody {
		var ret = requestBody
		ret["pushRegId"] = ret["pushRegistrationId"]
		ret["pushRegistrationId"] = nil
		ret["regEnabled"] = ret["isPushRegistrationEnabled"]
		ret["isPushRegistrationEnabled"] = nil
		ret["isPrimary"] = ret["isPrimaryDevice"]
		ret["isPrimaryDevice"] = nil
		return ret
	}
}
