//
//  MMNSESharedStorage.swift
//  MobileMessagingNotificationExtension
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

// NOTE: The receipt archive and app-group file naming are shared with DefaultSharedDataStorage in MobileMessaging. Keep both implementations in sync.
class MMNSESharedStorage {
    enum DeliveryReportUpdateResult: Equatable {
        case updated
        case receiptNotFound
        case failed
    }

    /// Keys of a receipt dictionary in the shared archive. The values are persisted and read by DefaultSharedDataStorage too, so they must never change.
    enum ReceiptKey {
        /// Original APNs payload of the message.
        static let payload = "p"
        /// `true` once a delivery report for the message was sent.
        static let deliveryReportSent = "dlr"
        /// Date the delivery report was sent.
        static let deliveryReportDate = "dlrd"
        /// Date this extension started sending the delivery report. While it is recent, the app leaves the receipt and its report to the extension.
        static let deliveryReportStartDate = "dlrs"
    }

    static let receiptFileNamePrefix = "com.infobip.mobile-messaging.receipts."
    static let deliveryReportLeaseDuration: TimeInterval = 60

    let applicationCode: String
    let storage: UserDefaults
    let receiptFileURL: URL

    init?(applicationCode: String, appGroupId: String, containerURL: URL? = nil) {
        guard let ud = UserDefaults(suiteName: appGroupId),
              let containerURL = containerURL ?? FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return nil
        }
        self.applicationCode = applicationCode
        self.storage = ud
        // The receipt file is not created here: an uncoordinated create could truncate receipts the app is writing.
        // A missing file is read as empty, and the first coordinated write creates it.
        self.receiptFileURL = Self.receiptFileURL(applicationCode: applicationCode, containerURL: containerURL)
    }

    func save(message: MMNSEMessage) {
        let messageDictionary = receiptDictionary(for: message)
        coordinatedWrite { url in
            guard var messages = loadMessages(at: url) else { return false }
            let messageId = message.messageId
            if let index = messages.firstIndex(where: { Self.messageId(in: $0) == messageId }) {
                let previous = messages[index]
                var updated = messageDictionary
                if previous[ReceiptKey.deliveryReportSent] as? Bool == true {
                    updated[ReceiptKey.deliveryReportSent] = true
                    updated[ReceiptKey.deliveryReportDate] = previous[ReceiptKey.deliveryReportDate]
                    updated[ReceiptKey.deliveryReportStartDate] = nil
                }
                messages[index] = updated
            } else {
                messages.append(messageDictionary)
            }
            return write(messages, to: url)
        }
    }

    func claimDeliveryReport(for message: MMNSEMessage, at date: Date = Date()) -> Bool {
        var claimed = false
        coordinatedWrite { url in
            guard var messages = loadMessages(at: url) else { return false }
            var receipt = receiptDictionary(for: message)
            receipt[ReceiptKey.deliveryReportStartDate] = date
            if let index = messages.firstIndex(where: { Self.messageId(in: $0) == message.messageId }) {
                let existing = messages[index]
                if existing[ReceiptKey.deliveryReportSent] as? Bool == true || Self.isDeliveryReportInProgress(existing, at: date) {
                    return true
                }
                messages[index] = receipt
            } else {
                messages.append(receipt)
            }
            claimed = write(messages, to: url)
            return claimed
        }
        return claimed
    }

    func markDeliveryReported(messageId: String, date: Date) -> DeliveryReportUpdateResult {
        var result: DeliveryReportUpdateResult = .failed
        let succeeded = coordinatedWrite { url in
            guard var messages = loadMessages(at: url) else { return false }
            guard let index = messages.firstIndex(where: { Self.messageId(in: $0) == messageId }) else {
                result = .receiptNotFound
                return true
            }
            messages[index][ReceiptKey.deliveryReportSent] = true
            messages[index][ReceiptKey.deliveryReportDate] = date
            messages[index][ReceiptKey.deliveryReportStartDate] = nil
            let writeSucceeded = write(messages, to: url)
            if writeSucceeded {
                result = .updated
            }
            return writeSucceeded
        }
        return succeeded ? result : .failed
    }

    /// Hands delivery reporting of the message over to the app, which reports it after consuming the receipt.
    func markDeliveryReportFailed(messageId: String) {
        coordinatedWrite { url in
            guard var messages = loadMessages(at: url) else { return false }
            guard let index = messages.firstIndex(where: { Self.messageId(in: $0) == messageId }) else { return true }
            messages[index][ReceiptKey.deliveryReportStartDate] = nil
            return write(messages, to: url)
        }
    }

    private func receiptDictionary(for message: MMNSEMessage) -> [String: Any] {
        var messageDictionary: [String: Any] = [
            ReceiptKey.payload: message.originalPayload,
            ReceiptKey.deliveryReportSent: message.isDeliveryReportSent]

        messageDictionary[ReceiptKey.deliveryReportDate] = message.deliveryReportedDate
        if !message.isDeliveryReportSent {
            messageDictionary[ReceiptKey.deliveryReportStartDate] = Date()
        }
        return messageDictionary
    }

    @discardableResult
    private func coordinatedWrite(_ operation: (URL) -> Bool) -> Bool {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var operationSucceeded = false
        coordinator.coordinate(writingItemAt: receiptFileURL, options: [], error: &coordinationError) { url in
            operationSucceeded = operation(url)
        }
        if let error = coordinationError {
            MMNSELogger.logError("could not coordinate shared receipt write: \(error)")
        } else if !operationSucceeded {
            MMNSELogger.logError("could not update shared receipt storage")
        }
        return coordinationError == nil && operationSucceeded
    }

    private func loadMessages(at url: URL) -> [[String: Any]]? {
        let currentMessages: [[String: Any]]
        do {
            let data = try Data(contentsOf: url)
            if data.isEmpty {
                currentMessages = []
            } else {
                currentMessages = unarchiveMessageDictionaries(fromData: data) ?? []
            }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            currentMessages = []
        } catch {
            MMNSELogger.logError("could not read shared receipt storage: \(error)")
            return nil
        }

        guard let legacyMessages = legacyMessageDictionaries() else { return currentMessages }
        let mergedMessages = Self.merge(legacyMessages, into: currentMessages)
        guard write(mergedMessages, to: url) else { return nil }
        storage.removeObject(forKey: applicationCode)
        storage.synchronize()
        return mergedMessages
    }

    private func legacyMessageDictionaries() -> [[String: Any]]? {
        if let data = storage.object(forKey: applicationCode) as? Data {
            return unarchiveMessageDictionaries(fromData: data)
        }
        return storage.object(forKey: applicationCode) as? [[String: Any]]
    }

    private func unarchiveMessageDictionaries(fromData data: Data) -> [[String: Any]]? {
        do {
            return try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSArray.self, NSDictionary.self, NSNull.self, NSString.self, NSNumber.self, NSDate.self],
                from: data
            ) as? [[String: Any]]
        } catch {
            MMNSELogger.logError("couldn't unarchive message objects with error: \(error)")
            return nil
        }
    }

    private func write(_ messages: [[String: Any]], to url: URL) -> Bool {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: messages, requiringSecureCoding: true)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            MMNSELogger.logError("failed to archive shared messages: \(error)")
            return false
        }
    }

    private static func merge(_ legacyMessages: [[String: Any]], into currentMessages: [[String: Any]]) -> [[String: Any]] {
        var messages = currentMessages
        for legacyMessage in legacyMessages {
            guard let messageId = messageId(in: legacyMessage) else {
                messages.append(legacyMessage)
                continue
            }
            if !messages.contains(where: { self.messageId(in: $0) == messageId }) {
                messages.append(legacyMessage)
            }
        }
        return messages
    }

    private static func isDeliveryReportInProgress(_ receipt: [String: Any], at date: Date) -> Bool {
        guard let startDate = receipt[ReceiptKey.deliveryReportStartDate] as? Date else { return false }
        let elapsed = date.timeIntervalSince(startDate)
        return elapsed >= 0 && elapsed < deliveryReportLeaseDuration
    }

    private static func messageId(in message: [String: Any]) -> String? {
        (message[ReceiptKey.payload] as? [String: Any])?["messageId"] as? String
    }

    private static func receiptFileURL(applicationCode: String, containerURL: URL) -> URL {
        let encodedCode = Data(applicationCode.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return containerURL.appendingPathComponent("\(receiptFileNamePrefix)\(encodedCode).archive")
    }
}
