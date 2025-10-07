// 
//  ChatExample/MobileChatExample/BadgeCounterHandler.swift
//  MobileChatExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UIKit

public struct BadgeCounterHandler {
    static func clearBadge() {
        UserDefaults.standard.set(0, forKey: "ChatExampleBadgeNumber")
        setBadge(0)
    }

    static func increaseBadge(by value: Int) -> Int {
        var badgeNumber = UserDefaults.standard.integer(forKey: "ChatExampleBadgeNumber")
        badgeNumber += value
        UserDefaults.standard.set(badgeNumber, forKey: "ChatExampleBadgeNumber")
        setBadge(badgeNumber)
        return badgeNumber
    }

    static private func setBadge(_ value: Int) {
        if #available(iOS 16.0, *) {
             UNUserNotificationCenter.current().requestAuthorization(options: .badge) { (authorised, error) in
                 guard authorised, error == nil else { return }
                 UNUserNotificationCenter.current().setBadgeCount(
                    value > 0 ? value : 0, withCompletionHandler: { _ in
                        /*  Do nothing, recoverable error */
                    }) }
        } else {
            /*
             You cannot alter the badge number within a UNNotificationServiceExtension in older iOS versions.
             Only options is to listen to incoming push notification and apply the counting in the parent app (it will work if it is in background, but badge count won't be updated if the app is killed)
             */
        }
    }
}
