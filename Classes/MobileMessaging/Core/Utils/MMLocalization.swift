//
//  MMLocalization.swift
//
//  Created by okoroleva on 27.07.17.
//
//

import Foundation

public class MMLocalization {
	static let sharedInstance = MMLocalization()
	public func localizedString(forKey key: String?, defaultString: String) -> String {
		guard let key = key else {
			return defaultString
		}
        return MMLocalization.languageBundle().localizedString(forKey: key, value: defaultString, table: "MobileMessaging")
	}
	public class func localizedString(forKey key: String?, defaultString: String) -> String {
		guard let key = key else {
			return defaultString
		}
        #if SWIFT_PACKAGE
        return NSLocalizedString(key, tableName: "MobileMessaging", bundle: Bundle.module, value: defaultString, comment: "")
        #else
		return MMLocalization.sharedInstance.localizedString(forKey: key, defaultString: defaultString)
        #endif
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

