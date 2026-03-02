// 
//  Example/Tests/MobileMessagingTests/MessageSeenTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
import CoreData
@testable import MobileMessaging


class MessageSeenTests: MMTestCase {


	func testSendSeenStatusUpdate() async throws {
		MMTestCase.startWithCorrectApplicationCode()

		let messageId = "m1"

		await withCheckedContinuation { continuation in
			mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": messageId]) { _ in
				continuation.resume()
			}
		}

		await MobileMessaging.setSeen(messageIds: [messageId])

		let ctx = self.storage.mainThreadManagedObjectContext!
		ctx.performAndWait {
			if let messages = MessageManagedObject.MM_findAllInContext(ctx) {
				let m1 = messages.filter({$0.messageId == "m1"}).first
				XCTAssertEqual(m1!.seenStatus, MMSeenStatus.SeenNotSent, "m1 must be seen and synced")
			} else {
				XCTFail("There should be some messages in database")
			}
		}
	}

	func testSendEmpty() async throws {
		MMTestCase.startWithCorrectApplicationCode()

		await withCheckedContinuation { continuation in
			mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": "m1"]) { _ in
				continuation.resume()
			}
		}

		await MobileMessaging.setSeen(messageIds: [])

		let ctx = self.storage.mainThreadManagedObjectContext!
		ctx.reset()
		ctx.performAndWait {
			if let messages = MessageManagedObject.MM_findAllInContext(ctx) {
				let m1 = messages.filter({$0.messageId == "m1"}).first!
				XCTAssertEqual(m1.seenStatus, MMSeenStatus.NotSeen, "m1 must be seen and synced")
				XCTAssertEqual(m1.seenDate, nil, "seen date must be nil")
			} else {
				XCTFail("There should be some messages in database")
			}
		}
	}

	func testSendSeenAgain() async throws {
		MMTestCase.startWithCorrectApplicationCode()

		// Receive messages sequentially
		for mId in ["m1", "m2", "m3"] {
			await withCheckedContinuation { continuation in
				mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": mId, "customPayload": ["tag1", "tag2"]]) { _ in
					continuation.resume()
				}
			}
		}

		// Set first batch as seen
		await MobileMessaging.setSeen(messageIds: ["m1", "m2"])

		var messagesSeenDates = [String: Date?]()
		let ctx1 = self.storage.mainThreadManagedObjectContext!
		ctx1.reset()
		ctx1.performAndWait {
			if let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", ["m1", "m2"]), context: ctx1), messages.count > 0 {
				for m in messages {
					XCTAssertEqual(m.seenStatus, MMSeenStatus.SeenNotSent)
					messagesSeenDates[m.messageId] = m.seenDate
				}

				if let m3 = messages.filter({ $0.messageId == "m3" }).first {
					XCTAssertEqual(m3.seenStatus, MMSeenStatus.NotSeen)
				}
			} else {
				XCTFail("There should be some messages in database")
			}
		}

		// Set all as seen (including already-seen ones)
		await MobileMessaging.setSeen(messageIds: ["m1", "m2", "m3"])

		let ctx2 = self.storage.mainThreadManagedObjectContext!
		ctx2.reset()
		ctx2.performAndWait {
			if let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", ["m1", "m2"]), context: ctx2), messages.count > 0 {
				for m in messages {
					XCTAssertEqual(m.seenStatus, MMSeenStatus.SeenNotSent)
					XCTAssertEqual(m.seenDate, messagesSeenDates[m.messageId]!)
				}
			} else {
				XCTFail("There should be some messages in database")
			}
		}
	}
}
