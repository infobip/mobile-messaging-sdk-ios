// 
//  RichNotificationsExtensions.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UserNotifications

extension MM_MTMessage {
    
    @discardableResult func downloadImageAttachment(appGroupId: String? = nil, completion: @escaping (URL?, Error?) -> Void) -> RetryableDownloadTask? {
        guard let contentURL = contentUrl?.safeUrl else {
            logDebug("could not init content url to download")
            completion(nil, nil)
            return nil
        }

        let destinationResolver: (URL, URLResponse) -> URL = { _, _ -> URL in
            //NOTE: appGroupId may be passed here to save file in app group to be fetched by main app afterwards. currently not implemented completely because some questions need to be answered: 1. does OS cleans up AppGroup/Library/Caches directory? if not, implement own purhing mechanism; 2. is simple file manager write safe enough to be used in shared container, whe writer/reader problem may happen.
            let ret = URL.attachmentDownloadDestinatioUrl(sourceUrl: contentURL, appGroupId: nil)
            return ret
        }

        let task = RetryableDownloadTask(attemptsCount: 3, contentUrl: contentURL, destinationResolver: destinationResolver, completion: completion)
        logDebug("downloading rich content for message...")
        task.resume()
        
        return task
    }

}

protocol AppGroupMessageStorage {
	init?(applicationCode: String, appGroupId: String)
	func save(message: MM_MTMessage)
	func drainMessages() -> [MM_MTMessage]
	func peekMessages() -> [MM_MTMessage]
	func messageIdsHandledByExtension() -> Set<String>
	func cleanupMessages()
}

// NOTE: Receipt archive and file naming are shared with MMNSESharedStorage in MobileMessagingNotificationExtension. Keep both implementations in sync.
class DefaultSharedDataStorage: AppGroupMessageStorage {
	enum DeliveryReportUpdateResult: Equatable {
		case updated
		case receiptNotFound
		case failed
	}

	/// Keys of a receipt dictionary in the shared archive. The values are persisted and written by MMNSESharedStorage too, so they must never change.
	enum ReceiptKey {
		/// Original APNs payload of the message.
		static let payload = "p"
		/// `true` once a delivery report for the message was sent.
		static let deliveryReportSent = "dlr"
		/// Date the delivery report was sent.
		static let deliveryReportDate = "dlrd"
		/// Date the notification service extension started sending the delivery report. Written by the extension only.
		static let deliveryReportStartDate = "dlrs"
	}

	static let receiptFileNamePrefix = "com.infobip.mobile-messaging.receipts."

	/// How long a receipt stays owned by the notification service extension after it started reporting delivery.
	/// The system terminates the extension about 30 seconds after it starts, so an older unreported receipt means the extension failed.
	static let deliveryReportLeaseDuration: TimeInterval = 60

	/// How long the app remembers a drained receipt. Local scheduling of a fetched message waits for its attachment download
	/// (up to 3 attempts of 20 seconds), so this must outlast it.
	static let drainedReceiptRetention: TimeInterval = 5 * 60
	static let drainedReceiptLimit = 100

	let applicationCode: String
	let storage: UserDefaults
	let receiptFileURL: URL
	private let now: () -> Date
	private var drainedReceiptDates = [String: Date]()
	private let drainedReceiptsLock = NSLock()

	required convenience init?(applicationCode: String, appGroupId: String) {
		guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
			return nil
		}
		self.init(applicationCode: applicationCode, appGroupId: appGroupId, containerURL: containerURL)
	}

	init?(applicationCode: String, appGroupId: String, containerURL: URL, now: @escaping () -> Date = Date.init) {
		guard let ud = UserDefaults(suiteName: appGroupId) else { return nil }
		self.applicationCode = applicationCode
		self.storage = ud
		self.now = now
		self.receiptFileURL = Self.receiptFileURL(applicationCode: applicationCode, containerURL: containerURL)
	}

	func save(message: MM_MTMessage) {
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
				}
				messages[index] = updated
			} else {
				messages.append(messageDictionary)
			}
			return write(messages, to: url)
		}
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
			let writeSucceeded = write(messages, to: url)
			if writeSucceeded {
				result = .updated
			}
			return writeSucceeded
		}
		return succeeded ? result : .failed
	}

	func drainMessages() -> [MM_MTMessage] {
		var messages: [MM_MTMessage] = []
		let date = now()
		let succeeded = coordinatedWrite { url in
			guard let savedMessages = loadMessages(at: url) else { return false }
			let reportsInProgress = savedMessages.filter { isDeliveryReportInProgress($0, at: date) }
			messages = savedMessages.filter { !isDeliveryReportInProgress($0, at: date) }.compactMap(message(from:))
			return write(reportsInProgress, to: url)
		}
		guard succeeded else { return [] }
		rememberDrainedReceipts(messages.map { $0.messageId }, at: date)
		return messages
	}

	func messageIdsHandledByExtension() -> Set<String> {
		let date = now()
		drainedReceiptsLock.lock()
		let recentlyDrained = drainedReceiptDates.filter { date.timeIntervalSince($0.value) < Self.drainedReceiptRetention }.keys
		drainedReceiptsLock.unlock()
		return Set(peekMessages().map { $0.messageId }).union(recentlyDrained)
	}

	private func rememberDrainedReceipts(_ messageIds: [String], at date: Date) {
		guard !messageIds.isEmpty else { return }
		drainedReceiptsLock.lock(); defer { drainedReceiptsLock.unlock() }
		drainedReceiptDates = drainedReceiptDates.filter { date.timeIntervalSince($0.value) < Self.drainedReceiptRetention }
		messageIds.forEach { drainedReceiptDates[$0] = date }
		if drainedReceiptDates.count > Self.drainedReceiptLimit {
			drainedReceiptDates.sorted { $0.value < $1.value }
				.prefix(drainedReceiptDates.count - Self.drainedReceiptLimit)
				.forEach { drainedReceiptDates[$0.key] = nil }
		}
	}

	func peekMessages() -> [MM_MTMessage] {
		var messages: [MM_MTMessage] = []
		let succeeded = coordinatedWrite { url in
			guard let savedMessages = loadMessages(at: url) else { return false }
			messages = savedMessages.compactMap(message(from:))
			return true
		}
		return succeeded ? messages : []
	}

	func cleanupMessages() {
		coordinatedWrite { url in
			guard loadMessages(at: url) != nil,
				  write([], to: url) else { return false }
			storage.removeObject(forKey: applicationCode)
			storage.synchronize()
			return true
		}
	}

	private func isDeliveryReportInProgress(_ receipt: MMStringKeyPayload, at date: Date) -> Bool {
		guard receipt[ReceiptKey.deliveryReportSent] as? Bool != true,
			  let startDate = receipt[ReceiptKey.deliveryReportStartDate] as? Date else { return false }
		let elapsed = date.timeIntervalSince(startDate)
		return elapsed >= 0 && elapsed < Self.deliveryReportLeaseDuration
	}

	private func message(from messageData: [String: Any]) -> MM_MTMessage? {
		guard let payload = messageData[ReceiptKey.payload] as? MMStringKeyPayload,
			  let dlrSent = messageData[ReceiptKey.deliveryReportSent] as? Bool else { return nil }
		return MM_MTMessage(payload: payload,
							deliveryMethod: .local,
							seenDate: nil,
							deliveryReportDate: messageData[ReceiptKey.deliveryReportDate] as? Date,
							seenStatus: .NotSeen,
							isDeliveryReportSent: dlrSent)
	}

	private func receiptDictionary(for message: MM_MTMessage) -> MMStringKeyPayload {
		var messageDictionary: MMStringKeyPayload = [ReceiptKey.payload: message.originalPayload, ReceiptKey.deliveryReportSent: message.isDeliveryReportSent]
		messageDictionary[ReceiptKey.deliveryReportDate] = message.deliveryReportedDate
		return messageDictionary
	}

	private func coordinatedWrite(_ operation: (URL) -> Bool) -> Bool {
		let coordinator = NSFileCoordinator(filePresenter: nil)
		var coordinationError: NSError?
		var operationSucceeded = false
		coordinator.coordinate(writingItemAt: receiptFileURL, options: [], error: &coordinationError) { url in
			operationSucceeded = operation(url)
		}
		if let error = coordinationError {
			MMLogError("[AppGroupMessageStorage] could not coordinate shared receipt write: \(error)")
		} else if !operationSucceeded {
			MMLogError("[AppGroupMessageStorage] could not update shared receipt storage")
		}
		return coordinationError == nil && operationSucceeded
	}

	private func loadMessages(at url: URL) -> [MMStringKeyPayload]? {
		let currentMessages: [MMStringKeyPayload]
		do {
			let data = try Data(contentsOf: url)
			if data.isEmpty {
				currentMessages = []
			} else {
				currentMessages = unarchiveMessageDictionaries(from: data) ?? []
			}
		} catch let error as CocoaError where error.code == .fileReadNoSuchFile {
			currentMessages = []
		} catch {
			MMLogError("[AppGroupMessageStorage] could not read shared receipt storage: \(error)")
			return nil
		}

		guard let legacyMessages = legacyMessageDictionaries() else { return currentMessages }
		let mergedMessages = Self.merge(legacyMessages, into: currentMessages)
		guard write(mergedMessages, to: url) else { return nil }
		storage.removeObject(forKey: applicationCode)
		storage.synchronize()
		return mergedMessages
	}

	private func legacyMessageDictionaries() -> [MMStringKeyPayload]? {
		if let data = storage.object(forKey: applicationCode) as? Data {
			return unarchiveMessageDictionaries(from: data)
		}
		return storage.object(forKey: applicationCode) as? [MMStringKeyPayload]
	}

	private func unarchiveMessageDictionaries(from data: Data) -> [MMStringKeyPayload]? {
		do {
			return try NSKeyedUnarchiver.unarchivedObject(
				ofClasses: [NSArray.self, NSDictionary.self, NSNull.self, NSString.self, NSNumber.self, NSDate.self],
				from: data
			) as? [MMStringKeyPayload]
		} catch {
			MMLogError("[AppGroupMessageStorage] couldn't unarchive message objects with error: \(error)")
			return nil
		}
	}

	private func write(_ messages: [MMStringKeyPayload], to url: URL) -> Bool {
		do {
			let data = try NSKeyedArchiver.archivedData(withRootObject: messages, requiringSecureCoding: true)
			try data.write(to: url, options: .atomic)
			return true
		} catch {
			MMLogError("[AppGroupMessageStorage] failed to archive shared messages: \(error)")
			return false
		}
	}

	private static func merge(_ legacyMessages: [MMStringKeyPayload], into currentMessages: [MMStringKeyPayload]) -> [MMStringKeyPayload] {
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

	private static func messageId(in message: MMStringKeyPayload) -> String? {
		(message[ReceiptKey.payload] as? MMStringKeyPayload)?["messageId"] as? String
	}

	private static func receiptFileURL(applicationCode: String, containerURL: URL) -> URL {
		let encodedCode = Data(applicationCode.utf8).base64EncodedString()
			.replacingOccurrences(of: "+", with: "-")
			.replacingOccurrences(of: "/", with: "_")
			.replacingOccurrences(of: "=", with: "")
		return containerURL.appendingPathComponent("\(receiptFileNamePrefix)\(encodedCode).archive")
	}
}
