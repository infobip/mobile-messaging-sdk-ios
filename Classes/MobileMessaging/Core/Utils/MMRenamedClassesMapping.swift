// 
//  MMRenamedClassesMapping.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
