//
//  InstallationDataMapper.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14/01/2019.
//

import Foundation

class InstallationDataMapper {
	class func requestPayload(currentInstallation: Installation, dirtyInstallation: Installation, internalData: InternalData) -> RequestBody {
		let currentDict = currentInstallation.dictionaryRepresentation
		let nonReportedDict = dirtyInstallation.dictionaryRepresentation
		var ret = deltaDict(currentDict, nonReportedDict)
		if internalData.systemDataHash != Int64(MobileMessaging.userAgent.systemData.hashValue) {
			ret.merge(MobileMessaging.userAgent.systemData.requestPayload, uniquingKeysWith: { (l, r) -> Any in
				return r
			})
		}
		ret["pushRegId"] = ret["pushRegistrationId"]
		ret["pushRegistrationId"] = nil
		ret["regEnabled"] = ret["isPushRegistrationEnabled"]
		ret["isPushRegistrationEnabled"] = nil
		ret["isPrimary"] = ret["isPrimaryDevice"]
		ret["isPrimaryDevice"] = nil
		return ret
	}
}
