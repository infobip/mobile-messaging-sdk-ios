//
//  MMLocalization.swift
//
//  Created by okoroleva on 27.07.17.
//
//

class MMLocalization {
	static let sharedInstance = MMLocalization()
	func localizedString(forKey key: String, defaultString: String) -> String {
		return MobileMessaging.bundle.localizedString(forKey: key, value: defaultString, table: "MobileMessaging")
	}
	class func localizedString(forKey key: String, defaultString: String) -> String {
		return MMLocalization.sharedInstance.localizedString(forKey: key, defaultString: defaultString)
	}
}
