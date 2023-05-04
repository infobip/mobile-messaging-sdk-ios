//
//  MMRenamedClassesMapping.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 02.03.2021.
//

import Foundation

extension NSKeyedUnarchiver {
    static func mm_setMappingForRenamedClasses() {
        setClass(MMInstallation.self, forClassName: "MobileMessaging.Installation")
        setClass(MMUser.self, forClassName: "MobileMessaging.User")
        setClass(MMPhone.self, forClassName: "MobileMessaging.Phone")
        setClass(MMEmail.self, forClassName: "MobileMessaging.Email")
        setClass(MMDateTime.self, forClassName: "MobileMessaging.DateTime")
    }
}
