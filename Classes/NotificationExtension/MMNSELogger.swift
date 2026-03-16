//
//  MMNSELogger.swift
//  MobileMessagingNotificationExtension
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

enum MMNSELogger {
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime, .withFractionalSeconds]
        return formatter
    }()

    static func logDebug(_ message: String) {
        print("\(dateFormatter.string(from: Date())) [MobileMessagingNotificationExtension] 🛠 \(message)")
    }

    static func logError(_ message: String) {
        print("\(dateFormatter.string(from: Date())) [MobileMessagingNotificationExtension] ‼️ \(message)")
    }
}
