//
//  File.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 14.06.2020.
//

import Foundation
class ChatLocalization {
    class func localizedString(forKey key: String?, defaultString: String) -> String {
        guard let key = key else {
            return defaultString
        }
        return MobileMessaging.bundle.localizedString(forKey: key, value: defaultString, table: "InAppChat")
    }
}
