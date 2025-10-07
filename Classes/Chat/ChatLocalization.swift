// 
//  ChatLocalization.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

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
        guard let langBundleURL = MMInAppChatService.resourceBundle.url(
            forResource: MMLanguage.sessionLanguage.stringValue,
            withExtension: "lproj"),
            let langBundle = Bundle(url: langBundleURL) else {
            return MMInAppChatService.resourceBundle
        }
        return langBundle
    }
}
