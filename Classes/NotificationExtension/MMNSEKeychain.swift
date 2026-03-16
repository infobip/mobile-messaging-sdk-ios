//
//  MMNSEKeychain.swift
//  MobileMessagingNotificationExtension
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import Security

struct MMNSEKeychain {
    private let keyPrefix: String
    private let accessGroup: String?

    init(accessGroup: String?) {
        let sharedPrefix = accessGroup == nil ? "" : "shared."
        let bundleId = Bundle.mainAppBundle.bundleIdentifier ?? ""
        self.keyPrefix = sharedPrefix + MMNSEConsts.KeychainKeys.prefix + "/" + bundleId
        self.accessGroup = accessGroup
    }

    var applicationCode: String? {
        return get(MMNSEConsts.KeychainKeys.appCode)
    }

    var pushRegId: String? {
        return get(MMNSEConsts.KeychainKeys.pushRegId)
    }

    private func get(_ key: String) -> String? {
        let prefixedKey = keyPrefix + key

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: prefixedKey,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        guard status == noErr, let data = result as? Data else {
            return nil
        }

        return NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String?
    }
}
