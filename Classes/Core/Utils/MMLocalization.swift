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
        return MMLocalization.languageBundle().localizedString(forKey: key, value: defaultString, table: "MobileMessaging")
	}
	class func localizedString(forKey key: String?, defaultString: String) -> String {
		guard let key = key else {
			return defaultString
		}
		return MMLocalization.sharedInstance.localizedString(forKey: key, defaultString: defaultString)
	}
    
    private class func languageBundle() -> Bundle {
        guard let langBundleURL = MobileMessaging.resourceBundle.url(
            forResource: MMLanguage.sessionLanguage.stringValue, // if never set, default will be current installation language
            withExtension: "lproj"),
            let langBundle = Bundle(url: langBundleURL) else {
            return MobileMessaging.resourceBundle
        }
        return langBundle
    }
}
