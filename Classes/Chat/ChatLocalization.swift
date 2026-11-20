// 
//  ChatLocalization.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
#if SWIFT_PACKAGE
@_spi(InAppChat) import MobileMessaging
#endif

class ChatLocalization {
    class func localizedString(forKey key: String?, defaultString: String) -> String {
        guard let key = key else {
            return defaultString
        }
        return ChatLocalization.languageBundle().localizedString(
            forKey: key,
            value: defaultString,
            table: "InAppChat")
    }
    
    private class func languageBundle() -> Bundle {
        MMLocalizationBundleResolver.bundle(
            for: MMInAppChatService.resourceBundle,
            languageCode: MMLanguage.resourceLanguageCode
        )
    }
}
