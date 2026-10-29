// 
//  Example/Tests/MobileMessagingTests/LocalMessageFetchingTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
import Foundation
import UserNotifications
@testable import MobileMessaging

class UserNotificationCenterStorageStub : UserNotificationCenterStorage {
	func getDeliveredMessages(completionHandler: @escaping ([MM_MTMessage]) -> Swift.Void) {
		completionHandler([MM_MTMessage(payload: apnsNormalMessagePayload("m1"), deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!])
	}
}

class NotificationExtensionStorageStub: AppGroupMessageStorage {
	convenience init?() {
		self.init(applicationCode: "", appGroupId: "")
	}
	
	required init?(applicationCode: String, appGroupId: String) {}
	
	func save(message: MM_MTMessage) {}
	
	func drainMessages() -> [MM_MTMessage] {
		return [MM_MTMessage(payload: apnsNormalMessagePayload("m2"), deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!]
	}

	func peekMessages() -> [MM_MTMessage] { return [] }

	func messageIdsHandledByExtension() -> Set<String> { return [] }

	func cleanupMessages() {}
}

class SharedReceiptStorageStub: AppGroupMessageStorage {
	private let lock = NSLock()
	private var receipts = [MM_MTMessage]()

	convenience init?() {
		self.init(applicationCode: "", appGroupId: "")
	}

	required init?(applicationCode: String, appGroupId: String) {}

	func save(message: MM_MTMessage) {
		lock.lock(); defer { lock.unlock() }
		receipts.append(message)
	}

	func drainMessages() -> [MM_MTMessage] {
		lock.lock(); defer { lock.unlock() }
		let consumed = receipts
		receipts = []
		return consumed
	}

	func peekMessages() -> [MM_MTMessage] {
		lock.lock(); defer { lock.unlock() }
		return receipts
	}

	func messageIdsHandledByExtension() -> Set<String> {
		return Set(peekMessages().map { $0.messageId })
	}

	func cleanupMessages() {
		lock.lock(); defer { lock.unlock() }
		receipts = []
	}
}

func nseReceipt(_ messageId: String, deliveryReportSent: Bool) -> MM_MTMessage {
	return MM_MTMessage(payload: apnsNormalMessagePayload(messageId), deliveryMethod: .local, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: deliveryReportSent)!
}

class LocalMessageFetchingTests : MMTestCase {
	
	func testThatMessagesFetchedLocallyAreConsideredAsDeliveredAndServerDuplicatesAreNotPresented() {
        MMTestCase.startWithCorrectApplicationCode()

		weak let expectation = self.expectation(description: "server sync finished")
		var dlrs = [String]()
		var receivedM2Count = 0
		var scheduledM2Count = 0
		let delegate = MessageHandlingDelegateMock()
		delegate.didReceiveNewMessageHandler = { message in
			if message.messageId == "m2" { receivedM2Count += 1 }
		}
		delegate.willScheduleLocalNotification = { message in
			if message.messageId == "m2" { scheduledM2Count += 1 }
		}
		MobileMessaging.messageHandlingDelegate = delegate

		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.userNotificationCenterStorage = UserNotificationCenterStorageStub()
		mobileMessagingInstance.sharedNotificationExtensionStorage = NotificationExtensionStorageStub()

		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.syncMessagesClosure = { appcode, pushRegistrationId, body -> MessagesSyncResult in
			if let dls = body["drIDs"] as? [String] {
				dlrs.append(contentsOf: dls)
			}
			let duplicatePayload: [String: Any] = ["messageId": "m2", "aps": ["alert": "Hello"]]
			return MessagesSyncResult.Success(MessagesSyncResponse(json: JSON(["payloads": [duplicatePayload]]))!)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		mobileMessagingInstance.messageHandler.syncWithServer(userInitiated: false) { _ in
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 10) { _ in
			XCTAssert(dlrs.contains("m1"))
			XCTAssert(dlrs.contains("m2"))
			XCTAssertEqual(receivedM2Count, 1)
			XCTAssertEqual(scheduledM2Count, 0)
			MobileMessaging.messageHandlingDelegate = nil
		}
	}

	// Delivery reporting of a receipt belongs to the extension until the app consumes it, so the app only excludes the message from the fetch.
	func testThatSilentPushFetchSendsPendingReceiptAsArchivedMessageAndDoesNotPresentIt() {
		assertSilentPushFetchSendsReceiptAsArchivedMessage(deliveryReportSent: false)
	}

	func testThatSilentPushFetchSendsReportedReceiptAsArchivedMessageAndDoesNotPresentIt() {
		assertSilentPushFetchSendsReceiptAsArchivedMessage(deliveryReportSent: true)
	}

	private func assertSilentPushFetchSendsReceiptAsArchivedMessage(deliveryReportSent: Bool, line: UInt = #line) {
		let receiptStorage = SharedReceiptStorageStub()!
		var requestedDrIds = [String]()
		var requestedArchiveIds = [String]()
		let result = runSilentPushFetch(receiptStorage: receiptStorage,
										beforeSilentPush: { receiptStorage.save(message: nseReceipt("m2", deliveryReportSent: deliveryReportSent)) },
										onServerFetch: { body in
											requestedDrIds = body["drIDs"] as? [String] ?? []
											requestedArchiveIds = body["mIDs"] as? [String] ?? []
										})

		XCTAssertFalse(requestedDrIds.contains("m2"), line: line)
		XCTAssert(requestedArchiveIds.contains("m2"), line: line)
		XCTAssertEqual(result.scheduledM2Count, 0, line: line)
	}

	func testThatMessageWithReceiptSavedDuringFetchIsNotPresentedLocally() {
		let receiptStorage = SharedReceiptStorageStub()!
		let result = runSilentPushFetch(receiptStorage: receiptStorage,
										beforeSilentPush: {},
										onServerFetch: { _ in receiptStorage.save(message: nseReceipt("m2", deliveryReportSent: false)) })

		XCTAssertEqual(result.receivedM2Count, 1)
		XCTAssertEqual(result.scheduledM2Count, 0)
	}

	func testThatFetchedMessageWithoutReceiptIsStillPresentedLocally() {
		let result = runSilentPushFetch(receiptStorage: SharedReceiptStorageStub()!, beforeSilentPush: {}, onServerFetch: { _ in })

		XCTAssertEqual(result.receivedM2Count, 1)
		XCTAssertEqual(result.scheduledM2Count, 1)
	}

	// Reviewer reproduction: the NSE saves the receipt while the fetched message is being inserted into message storage.
	func testThatMessageWithReceiptSavedDuringStorageInsertionIsNotPresentedLocally() {
		let receiptStorage = SharedReceiptStorageStub()!
		let messageStorage = ReceiptSavingMessageStorageStub(onInsert: { messages in
			if messages.contains(where: { $0.messageId == "m2" }) {
				receiptStorage.save(message: nseReceipt("m2", deliveryReportSent: false))
			}
		})
		let result = runSilentPushFetch(receiptStorage: receiptStorage,
										beforeSilentPush: {},
										onServerFetch: { _ in },
										configure: { mm in
											mm.messageStorages[MessageStorageKind.messages.rawValue] = MessageStorageQueuedAdapter.makeMessagesStoragaAdapter(storage: messageStorage)
										})

		XCTAssertEqual(result.receivedM2Count, 1)
		XCTAssertEqual(result.scheduledM2Count, 0)
	}

	// The NSE saves the receipt after the presentation decision, while the local notification's attachment is downloading.
	func testThatNotificationIsNotScheduledWhenReceiptIsSavedBeforeSchedulingCompletes() {
		let receiptStorage = SharedReceiptStorageStub()!
		weak let scheduleDecisionMade = expectation(description: "final scheduling decision made")
		var addedRequestIds = [String]()
		let originalAdd = LocalNotifications.addNotificationRequest
		LocalNotifications.addNotificationRequest = { request, completion in
			addedRequestIds.append(request.identifier)
			completion(nil)
		}
		defer { LocalNotifications.addNotificationRequest = originalAdd }

		let message = MM_MTMessage(payload: apnsNormalMessagePayload("m2"), deliveryMethod: .pull, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		// Equivalent to the moment between the presentation decision and UNUserNotificationCenter.add.
		receiptStorage.save(message: nseReceipt("m2", deliveryReportSent: false))
		LocalNotifications.scheduleUserNotification(with: message, isPresentedByExtension: {
			receiptStorage.peekMessages().contains { $0.messageId == "m2" }
		}, completion: { scheduleDecisionMade?.fulfill() })

		waitForExpectations(timeout: 5) { _ in }
		XCTAssert(addedRequestIds.isEmpty)
	}

	func testThatNotificationIsScheduledWhenNoReceiptExistsAtSchedulingTime() {
		weak let scheduled = expectation(description: "notification scheduled")
		var addedRequestIds = [String]()
		let originalAdd = LocalNotifications.addNotificationRequest
		LocalNotifications.addNotificationRequest = { request, completion in
			addedRequestIds.append(request.identifier)
			completion(nil)
		}
		defer { LocalNotifications.addNotificationRequest = originalAdd }

		let message = MM_MTMessage(payload: apnsNormalMessagePayload("m2"), deliveryMethod: .pull, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		LocalNotifications.scheduleUserNotification(with: message, isPresentedByExtension: { false }, completion: { scheduled?.fulfill() })

		waitForExpectations(timeout: 5) { _ in }
		XCTAssertEqual(addedRequestIds, ["m2"])
	}

	/// Delivers silent push "s1" through didReceiveRemoteNotification; the server answers that fetch with visible message "m2".
	private func runSilentPushFetch(receiptStorage: SharedReceiptStorageStub,
									beforeSilentPush: @escaping () -> Void,
									onServerFetch: @escaping (RequestBody) -> Void,
									configure: (MobileMessaging) -> Void = { _ in }) -> (receivedM2Count: Int, scheduledM2Count: Int) {
		MMTestCase.startWithCorrectApplicationCode()
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		configure(mobileMessagingInstance)

		weak let expectation = self.expectation(description: "silent push handled")
		var receivedM2Count = 0
		var scheduledM2Count = 0
		let delegate = MessageHandlingDelegateMock()
		delegate.didReceiveNewMessageHandler = { message in
			if message.messageId == "m2" { receivedM2Count += 1 }
		}
		delegate.willScheduleLocalNotification = { message in
			if message.messageId == "m2" { scheduledM2Count += 1 }
		}
		MobileMessaging.messageHandlingDelegate = delegate

		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.syncMessagesClosure = { _, _, body -> MessagesSyncResult in
			guard (body["drIDs"] as? [String])?.contains("s1") == true else {
				return MessagesSyncResult.Success(MessagesSyncResponse(json: JSON(["payloads": []]))!)
			}
			onServerFetch(body)
			return MessagesSyncResult.Success(MessagesSyncResponse(json: JSON(["payloads": [apnsNormalMessagePayload("m2")]]))!)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		// The initial sync only drains the startup fetch, so the silent push fetch below runs on its own.
		mobileMessagingInstance.messageHandler.syncWithServer(userInitiated: false) { _ in
			self.mobileMessagingInstance.sharedNotificationExtensionStorage = receiptStorage
			beforeSilentPush()
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: false, userInfo: apnsSilentMessagePayload("s1")) { _ in
				expectation?.fulfill()
			}
		}

		waitForExpectations(timeout: 10) { _ in }
		MobileMessaging.messageHandlingDelegate = nil
		return (receivedM2Count, scheduledM2Count)
	}
}

/// Message storage that lets a test act while incoming messages are being inserted.
class ReceiptSavingMessageStorageStub: MessageStorageStub {
	private let onInsert: ([MMBaseMessage]) -> Void

	init(onInsert: @escaping ([MMBaseMessage]) -> Void) {
		self.onInsert = onInsert
		super.init()
	}

	override var queue: DispatchQueue {
		return DispatchQueue.global(qos: .default)
	}

	override func insert(incoming messages: [MMBaseMessage], completion: @escaping () -> Void) {
		onInsert(messages)
		super.insert(incoming: messages, completion: completion)
	}
}
