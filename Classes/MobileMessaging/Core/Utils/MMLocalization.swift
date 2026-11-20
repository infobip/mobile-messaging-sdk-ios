// 
//  MMLocalization.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

@_spi(InAppChat) public enum MMLocalizationBundleResolver {
    private struct CacheKey: Hashable {
        let resourceBundlePath: String
        let languageCode: String
    }

    private static let lock = NSLock()
    private static var cachedBundles: [CacheKey: Bundle] = [:]

    public static func bundle(for resourceBundle: Bundle, languageCode: String) -> Bundle {
        let key = CacheKey(
            resourceBundlePath: resourceBundle.bundleURL.standardizedFileURL.path,
            languageCode: languageCode
        )

        lock.lock()
        defer { lock.unlock() }

        if let cachedBundle = cachedBundles[key] {
            return cachedBundle
        }

        let localizedBundle: Bundle
        if let languageBundleURL = resourceBundle.url(forResource: languageCode, withExtension: "lproj"),
           let languageBundle = Bundle(url: languageBundleURL) {
            localizedBundle = languageBundle
        } else {
            localizedBundle = resourceBundle
        }
        cachedBundles[key] = localizedBundle
        return localizedBundle
    }
}

public class MMLocalization {
	static let sharedInstance = MMLocalization()
	public func localizedString(forKey key: String?, defaultString: String) -> String {
		guard let key = key else {
			return defaultString
		}
        return MMLocalization.languageBundle().localizedString(forKey: key, value: defaultString, table: "MobileMessaging")
	}

	public class func localizedString(forKey key: String?, defaultString: String) -> String {
		return MMLocalization.sharedInstance.localizedString(forKey: key, defaultString: defaultString)
	}

    private class func languageBundle() -> Bundle {
        MMLocalizationBundleResolver.bundle(
            for: MobileMessaging.resourceBundle,
            languageCode: MMLanguage.resourceLanguageCode
        )
    }
}

