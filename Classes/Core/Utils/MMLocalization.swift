//
//  MMLocalization.swift
//
//  Created by okoroleva on 27.07.17.
//
//

class MMLocalization {
	static let sharedInstance = MMLocalization()
	func localizedString(forKey key: String?, defaultString: String) -> String {
		guard let key = key else {
			return defaultString
		}
        return MobileMessaging.resourceBundle.localizedString(forKey: key, value: defaultString, table: "MobileMessaging")
	}
	class func localizedString(forKey key: String?, defaultString: String) -> String {
		guard let key = key else {
			return defaultString
		}
		return MMLocalization.sharedInstance.localizedString(forKey: key, defaultString: defaultString)
	}
}

