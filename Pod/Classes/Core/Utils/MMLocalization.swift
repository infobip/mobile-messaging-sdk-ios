//
//  MMLocalization.swift
//
//  Created by okoroleva on 27.07.17.
//
//

class MMLocalization {
	static let sharedInstance = MMLocalization()
	let bundle: Bundle?
	init() {
		bundle = Bundle(identifier: "org.cocoapods.MobileMessaging")
	}
	func localizedString(forKey key: String, defaultString: String) -> String {
		guard let bundle = bundle else {
			return defaultString
		}
		return bundle.localizedString(forKey: key, value: defaultString, table: "MobileMessaging")
	}
	class func localizedString(forKey key: String, defaultString: String) -> String {
		return MMLocalization.sharedInstance.localizedString(forKey: key, defaultString: defaultString)
	}
}
