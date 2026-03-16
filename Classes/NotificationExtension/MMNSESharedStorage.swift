//
//  MMNSESharedStorage.swift
//  MobileMessagingNotificationExtension
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

// NOTE: Storage format (keys "p", "dlr", "dlrd" and NSKeyedArchiver serialization) is shared with DefaultSharedDataStorage in MobileMessaging module. Any changes here must be mirrored there.
class MMNSESharedStorage {
    let applicationCode: String
    let storage: UserDefaults

    init?(applicationCode: String, appGroupId: String) {
        guard let ud = UserDefaults(suiteName: appGroupId) else {
            return nil
        }
        self.applicationCode = applicationCode
        self.storage = ud
    }

    func save(message: MMNSEMessage) {
        var savedMessageDicts = retrieveSavedPayloadDictionaries()
        var msgDict: [String: Any] = ["p": message.originalPayload, "dlr": message.isDeliveryReportSent]
        msgDict["dlrd"] = message.deliveryReportedDate
        savedMessageDicts.append(msgDict)
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: savedMessageDicts, requiringSecureCoding: true)
            storage.set(data, forKey: applicationCode)
            storage.synchronize()
        } catch {
            MMNSELogger.logError("failed to archive message \(message.messageId): \(error)")
        }
    }

    private func retrieveSavedPayloadDictionaries() -> [[String: Any]] {
        if let data = storage.object(forKey: applicationCode) as? Data,
           let dictionaries = unarchiveMessageDictionaries(fromData: data) {
            return dictionaries
        } else if let dictionaries = storage.object(forKey: applicationCode) as? [[String: Any]] {
            return dictionaries
        }
        return []
    }

    private func unarchiveMessageDictionaries(fromData data: Data) -> [[String: Any]]? {
        do {
            return try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSArray.self, NSDictionary.self, NSNull.self, NSString.self, NSNumber.self, NSDate.self],
                from: data
            ) as? [[String: Any]]
        } catch {
            MMNSELogger.logError("couldn't unarchive message objects with error: \(error)")
        }
        return nil
    }
}
