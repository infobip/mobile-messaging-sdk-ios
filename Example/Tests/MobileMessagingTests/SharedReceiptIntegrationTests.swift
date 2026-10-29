//
//  Example/Tests/MobileMessagingTests/SharedReceiptIntegrationTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
import Foundation
@testable import MobileMessaging
@testable import MobileMessagingNotificationExtension

/// Exercises the receipt handoff between the notification service extension and the app through the real shared archive.
class SharedReceiptIntegrationTests: XCTestCase {
	private let appGroupId = "com.infobip.test.receipt-integration.\(UUID().uuidString)"
	private let applicationCode = "test-app-code"
	private let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
	/// Shifts the app's clock relative to the real clock the extension storage uses.
	private var appClockOffset: TimeInterval = 0

	override func setUp() {
		super.setUp()
		try! FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
	}

	override func tearDown() {
		UserDefaults.standard.removePersistentDomain(forName: appGroupId)
		try? FileManager.default.removeItem(at: containerURL)
		super.tearDown()
	}

	private func makeAppStorage() -> DefaultSharedDataStorage {
		DefaultSharedDataStorage(applicationCode: applicationCode, appGroupId: appGroupId, containerURL: containerURL, now: { Date().addingTimeInterval(self.appClockOffset) })!
	}

	private func makeNSEStorage() -> MMNSESharedStorage {
		MMNSESharedStorage(applicationCode: applicationCode, appGroupId: appGroupId, containerURL: containerURL)!
	}

	private func makeNSEMessage(_ messageId: String) -> MMNSEMessage {
		MMNSEMessage(payload: ["messageId": messageId, "aps": ["alert": "Hello"]])!
	}

	func testReceiptKeysAndFileNameMatchBetweenExtensionAndApp() {
		typealias AppKey = DefaultSharedDataStorage.ReceiptKey
		typealias NSEKey = MMNSESharedStorage.ReceiptKey
		XCTAssertEqual(AppKey.payload, NSEKey.payload)
		XCTAssertEqual(AppKey.deliveryReportSent, NSEKey.deliveryReportSent)
		XCTAssertEqual(AppKey.deliveryReportDate, NSEKey.deliveryReportDate)
		XCTAssertEqual(AppKey.deliveryReportStartDate, NSEKey.deliveryReportStartDate)
		XCTAssertEqual(makeAppStorage().receiptFileURL, makeNSEStorage().receiptFileURL)
	}

	// Reviewer scenario: the app syncs while the extension's delivery report request is in flight.
	func testAppDoesNotConsumeReceiptWhileExtensionIsReporting() {
		let appStorage = makeAppStorage()
		let nseStorage = makeNSEStorage()
		let message = makeNSEMessage("in-flight")

		nseStorage.save(message: message) // extension request is now in flight

		XCTAssertTrue(appStorage.drainMessages().isEmpty)
		XCTAssertEqual(appStorage.peekMessages().map(\.messageId), ["in-flight"])

		XCTAssertEqual(nseStorage.markDeliveryReported(messageId: message.messageId, date: Date()), .updated)

		let consumed = appStorage.drainMessages()
		XCTAssertEqual(consumed.map(\.messageId), ["in-flight"])
		XCTAssertTrue(consumed.first?.isDeliveryReportSent == true)
		XCTAssertTrue(appStorage.drainMessages().isEmpty)
	}

	func testFailedExtensionReportHandsReceiptToAppImmediately() {
		let appStorage = makeAppStorage()
		let nseStorage = makeNSEStorage()
		let message = makeNSEMessage("failed-report")

		nseStorage.save(message: message)
		nseStorage.markDeliveryReportFailed(messageId: message.messageId)

		let consumed = appStorage.drainMessages()
		XCTAssertEqual(consumed.map(\.messageId), ["failed-report"])
		XCTAssertTrue(consumed.first?.isDeliveryReportSent == false)
	}

	// The extension was terminated before it could report success or failure.
	func testAppConsumesUnreportedReceiptAfterLeaseExpires() {
		let appStorage = makeAppStorage()
		let nseStorage = makeNSEStorage()
		nseStorage.save(message: makeNSEMessage("terminated"))

		appClockOffset = DefaultSharedDataStorage.deliveryReportLeaseDuration + 1

		let consumed = appStorage.drainMessages()
		XCTAssertEqual(consumed.map(\.messageId), ["terminated"])
		XCTAssertTrue(consumed.first?.isDeliveryReportSent == false)
	}

	func testLeaseStartDateInTheFutureDoesNotKeepReceiptForever() {
		let appStorage = makeAppStorage()
		makeNSEStorage().save(message: makeNSEMessage("clock-changed"))

		appClockOffset = -3600

		XCTAssertEqual(appStorage.drainMessages().map(\.messageId), ["clock-changed"])
	}

	func testConsumeKeepsOnlyReceiptsBeingReported() {
		let appStorage = makeAppStorage()
		let nseStorage = makeNSEStorage()
		let reported = makeNSEMessage("reported")
		nseStorage.save(message: reported)
		XCTAssertEqual(nseStorage.markDeliveryReported(messageId: reported.messageId, date: Date()), .updated)
		nseStorage.save(message: makeNSEMessage("in-flight"))

		XCTAssertEqual(appStorage.drainMessages().map(\.messageId), ["reported"])
		XCTAssertEqual(appStorage.peekMessages().map(\.messageId), ["in-flight"])
	}

	// Receipts written by an older extension have no lease, so they are consumed as before.
	func testReceiptWithoutLeaseIsConsumedImmediately() {
		let appStorage = makeAppStorage()
		appStorage.save(message: MM_MTMessage(payload: ["messageId": "legacy", "aps": ["alert": "Hello"]],
											  deliveryMethod: .undefined,
											  seenDate: nil,
											  deliveryReportDate: nil,
											  seenStatus: .NotSeen,
											  isDeliveryReportSent: false)!)

		XCTAssertEqual(appStorage.drainMessages().map(\.messageId), ["legacy"])
	}
}

/// Runs the app's real sync path against receipts written by the real extension storage, counting delivery reports from both processes.
class SharedReceiptHandoffTests: MMTestCase {
	private let appGroupId = "com.infobip.test.receipt-handoff.\(UUID().uuidString)"
	private let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
	/// Shifts the app's clock relative to the real clock the extension storage uses.
	private var appClockOffset: TimeInterval = 0
	private let lock = NSLock()
	private var appReportedIds = [String]()

	override func setUp() {
		super.setUp()
		try! FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
	}

	override func tearDown() {
		super.tearDown()
		UserDefaults.standard.removePersistentDomain(forName: appGroupId)
		try? FileManager.default.removeItem(at: containerURL)
	}

	private func startApp() -> MMNSESharedStorage {
		MMTestCase.startWithCorrectApplicationCode()
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.userNotificationCenterStorage = EmptyUserNotificationCenterStorageStub()
		mobileMessagingInstance.sharedNotificationExtensionStorage = DefaultSharedDataStorage(applicationCode: mobileMessagingInstance.applicationCode, appGroupId: appGroupId, containerURL: containerURL, now: { Date().addingTimeInterval(self.appClockOffset) })

		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.syncMessagesClosure = { _, _, body -> MessagesSyncResult in
			self.lock.lock(); defer { self.lock.unlock() }
			self.appReportedIds.append(contentsOf: body["drIDs"] as? [String] ?? [])
			return MessagesSyncResult.Success(MessagesSyncResponse(json: JSON(["payloads": []]))!)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		return MMNSESharedStorage(applicationCode: mobileMessagingInstance.applicationCode, appGroupId: appGroupId, containerURL: containerURL)!
	}

	private func syncApp() {
		weak let synced = expectation(description: "app synced")
		mobileMessagingInstance.messageHandler.syncWithServer(userInitiated: false) { _ in synced?.fulfill() }
		waitForExpectations(timeout: 10) { _ in }
	}

	private func reportCount(for messageId: String) -> Int {
		lock.lock(); defer { lock.unlock() }
		return appReportedIds.filter { $0 == messageId }.count
	}

	private func persistedMessage(_ messageId: String) -> (exists: Bool, reportSent: Bool) {
		var result = (exists: false, reportSent: false)
		let ctx = storage.mainThreadManagedObjectContext!
		ctx.reset()
		ctx.performAndWait {
			if let message = MessageManagedObject.MM_findFirstWithPredicate(NSPredicate(format: "messageId == %@", messageId), context: ctx) {
				result = (true, message.reportSent)
			}
		}
		return result
	}

	// Reviewer scenario: pause the extension request after save, sync the app, then complete the request.
	func testExtensionReportInFlightDuringAppSyncIsReportedOnlyByExtension() {
		let nseStorage = startApp()
		let message = MMNSEMessage(payload: apnsNormalMessagePayload("m1") as! [String: Any])!
		var extensionReportCount = 0

		nseStorage.save(message: message) // extension request paused here
		syncApp()
		XCTAssertFalse(persistedMessage("m1").exists)

		extensionReportCount += 1 // extension request completes
		XCTAssertEqual(nseStorage.markDeliveryReported(messageId: message.messageId, date: Date()), .updated)
		syncApp()

		XCTAssertEqual(extensionReportCount + reportCount(for: "m1"), 1)
		XCTAssertEqual(persistedMessage("m1").exists, true)
		XCTAssertEqual(persistedMessage("m1").reportSent, true)
	}

	func testFailedExtensionReportIsReportedOnceByApp() {
		let nseStorage = startApp()
		let message = MMNSEMessage(payload: apnsNormalMessagePayload("m1") as! [String: Any])!

		nseStorage.save(message: message)
		nseStorage.markDeliveryReportFailed(messageId: message.messageId)
		syncApp()
		syncApp()

		XCTAssertEqual(reportCount(for: "m1"), 1)
		XCTAssertEqual(persistedMessage("m1").reportSent, true)
	}

	func testTerminatedExtensionReportIsReportedOnceByAppAfterLeaseExpires() {
		let nseStorage = startApp()
		nseStorage.save(message: MMNSEMessage(payload: apnsNormalMessagePayload("m1") as! [String: Any])!)

		syncApp()
		XCTAssertEqual(reportCount(for: "m1"), 0)

		appClockOffset = DefaultSharedDataStorage.deliveryReportLeaseDuration + 1
		syncApp()
		syncApp()

		XCTAssertEqual(reportCount(for: "m1"), 1)
		XCTAssertEqual(persistedMessage("m1").reportSent, true)
	}
}

private class EmptyUserNotificationCenterStorageStub: UserNotificationCenterStorage {
	func getDeliveredMessages(completionHandler: @escaping ([MM_MTMessage]) -> Swift.Void) {
		completionHandler([])
	}
}

/// Holds the extension's delivery report HTTP requests until a test releases them, and counts them.
class GatedDeliveryReportURLProtocol: URLProtocol {
	private static let lock = NSLock()
	private static var gate: DispatchSemaphore?
	private static var _reportedIds = [String]()
	static var failRequests = false
	static var onRequestStarted: (() -> Void)?

	static var reportedIds: [String] {
		lock.lock(); defer { lock.unlock() }
		return _reportedIds
	}

	static func reset(holdRequests: Bool) {
		lock.lock(); defer { lock.unlock() }
		gate = holdRequests ? DispatchSemaphore(value: 0) : nil
		_reportedIds = []
		failRequests = false
		onRequestStarted = nil
	}

	static func releaseOneRequest() {
		lock.lock(); let gate = gate; lock.unlock()
		gate?.signal()
	}

	override class func canInit(with request: URLRequest) -> Bool {
		request.url?.path == MMNSEConsts.API.deliveryReportPath
	}
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		let ids = Self.messageIds(in: request)
		Self.lock.lock(); let gate = Self.gate; Self.lock.unlock()
		DispatchQueue.global().async {
			Self.onRequestStarted?()
			gate?.wait()
			if Self.failRequests {
				self.client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
				return
			}
			Self.lock.lock(); Self._reportedIds.append(contentsOf: ids); Self.lock.unlock()
			let response = HTTPURLResponse(url: self.request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
			self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			self.client?.urlProtocolDidFinishLoading(self)
		}
	}

	override func stopLoading() {}

	private static func messageIds(in request: URLRequest) -> [String] {
		var data = request.httpBody
		if data == nil, let stream = request.httpBodyStream {
			stream.open(); defer { stream.close() }
			var buffer = Data()
			var chunk = [UInt8](repeating: 0, count: 1024)
			while stream.hasBytesAvailable {
				let count = stream.read(&chunk, maxLength: chunk.count)
				guard count > 0 else { break }
				buffer.append(chunk, count: count)
			}
			data = buffer
		}
		guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
		return json[MMNSEConsts.DeliveryReport.dlrMessageIds] as? [String] ?? []
	}
}

/// Runs the extension's real delivery reporting (with a held HTTP request) against the app's real sync path,
/// counting delivery reports sent by both processes.
class ExtensionAndAppDeliveryReportTests: MMTestCase {
	private let appGroupId = "com.infobip.test.dr-ownership.\(UUID().uuidString)"
	private let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
	private let lock = NSLock()
	private var appReportedIds = [String]()
	private var serverPayloads: () -> [[AnyHashable: Any]] = { [] }
	private var onServerFetch: () -> Void = {}
	private var appClockOffset: TimeInterval = 0

	override func setUp() {
		super.setUp()
		try! FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
		GatedDeliveryReportURLProtocol.reset(holdRequests: false)
	}

	override func tearDown() {
		super.tearDown()
		GatedDeliveryReportURLProtocol.reset(holdRequests: false)
		UserDefaults.standard.removePersistentDomain(forName: appGroupId)
		try? FileManager.default.removeItem(at: containerURL)
	}

	private func startApp() {
		MMTestCase.startWithCorrectApplicationCode()
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.userNotificationCenterStorage = EmptyNotificationCenterStorage()
		mobileMessagingInstance.sharedNotificationExtensionStorage = DefaultSharedDataStorage(applicationCode: mobileMessagingInstance.applicationCode, appGroupId: appGroupId, containerURL: containerURL, now: { Date().addingTimeInterval(self.appClockOffset) })

		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.syncMessagesClosure = { _, _, body -> MessagesSyncResult in
			self.lock.lock()
			self.appReportedIds.append(contentsOf: body["drIDs"] as? [String] ?? [])
			self.lock.unlock()
			// The response is decided before the hook runs, so the hook models work happening while the request is in flight.
			let payloads = self.serverPayloads()
			self.onServerFetch()
			return MessagesSyncResult.Success(MessagesSyncResponse(json: JSON(["payloads": payloads]))!)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider
	}

	private func makeExtension() -> MobileMessagingNotificationServiceExtension {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.protocolClasses = [GatedDeliveryReportURLProtocol.self]
		let defaults = UserDefaults(suiteName: appGroupId)!
		return MobileMessagingNotificationServiceExtension(
			appCode: mobileMessagingInstance.applicationCode,
			appGroupId: appGroupId,
			pushRegId: MMTestConstants.kTestCorrectInternalID,
			deliveryReporter: MMNSEDeliveryReporter(applicationCode: mobileMessagingInstance.applicationCode, appGroupId: appGroupId, storage: defaults, sessionConfiguration: configuration),
			sharedStorage: MMNSESharedStorage(applicationCode: mobileMessagingInstance.applicationCode, appGroupId: appGroupId, containerURL: containerURL))
	}

	private func nseMessage(_ messageId: String) -> MMNSEMessage {
		MMNSEMessage(payload: apnsNormalMessagePayload(messageId) as! [String: Any])!
	}

	/// Starts the extension's delivery reporting and returns once its HTTP request is in flight.
	private func startExtensionReport(_ nse: MobileMessagingNotificationServiceExtension, messageId: String) -> Task<Void, Never> {
		let started = DispatchSemaphore(value: 0)
		GatedDeliveryReportURLProtocol.onRequestStarted = { started.signal() }
		let task = Task { await nse.reportDelivery(for: self.nseMessage(messageId)) }
		XCTAssertEqual(started.wait(timeout: .now() + 5), .success, "extension request did not start")
		GatedDeliveryReportURLProtocol.onRequestStarted = nil
		return task
	}

	private func finish(_ task: Task<Void, Never>) {
		weak let finished = expectation(description: "extension reporting finished")
		Task { await task.value; finished?.fulfill() }
		waitForExpectations(timeout: 10) { _ in }
	}

	private func syncApp() {
		weak let synced = expectation(description: "app synced")
		mobileMessagingInstance.messageHandler.syncWithServer(userInitiated: false) { _ in synced?.fulfill() }
		waitForExpectations(timeout: 10) { _ in }
	}

	private func receiveSilentPush() {
		weak let handled = expectation(description: "silent push handled")
		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: false, userInfo: apnsSilentMessagePayload("s1")) { _ in handled?.fulfill() }
		waitForExpectations(timeout: 10) { _ in }
	}

	private func totalReports(for messageId: String) -> Int {
		lock.lock(); defer { lock.unlock() }
		return appReportedIds.filter { $0 == messageId }.count + GatedDeliveryReportURLProtocol.reportedIds.filter { $0 == messageId }.count
	}

	private func reportSent(_ messageId: String) -> Bool? {
		var result: Bool?
		let ctx = storage.mainThreadManagedObjectContext!
		ctx.reset()
		ctx.performAndWait {
			result = MessageManagedObject.MM_findFirstWithPredicate(NSPredicate(format: "messageId == %@", messageId), context: ctx)?.reportSent
		}
		return result
	}

	// Reviewer: pause the extension request after save, sync the app, then complete the request.
	func testRealExtensionRequestInFlightDuringAppSyncIsReportedOnce() {
		startApp()
		syncApp()
		GatedDeliveryReportURLProtocol.reset(holdRequests: true)
		let nse = makeExtension()

		let report = startExtensionReport(nse, messageId: "m1")
		syncApp()
		GatedDeliveryReportURLProtocol.releaseOneRequest()
		finish(report)
		syncApp()
		syncApp()

		XCTAssertEqual(totalReports(for: "m1"), 1)
		XCTAssertEqual(reportSent("m1"), true)
	}

	// handleMTMessages rebuilds in-app messages; a receipt the extension already reported must stay reported.
	func testInAppMessageReportedByExtensionIsNotReportedByApp() {
		startApp()
		syncApp()
		let nse = makeExtension()
		var payload = apnsNormalMessagePayload("inapp1") as! [String: Any]
		var internalData = payload["internalData"] as! [String: Any]
		internalData["inAppDetails"] = ["position": 1, "url": "https://www.infobip.com", "type": 1]
		payload["internalData"] = internalData

		finish(Task { await nse.reportDelivery(for: MMNSEMessage(payload: payload)!) })
		syncApp()
		syncApp()

		XCTAssertEqual(totalReports(for: "inapp1"), 1)
		XCTAssertEqual(reportSent("inapp1"), true)
	}

	// Reviewer: local scheduling of a fetched message is pending when the extension reports it and an app sync drains
	// the receipt. An empty archive must not be read as "the extension never handled this message".
	func testLocalNotificationIsNotScheduledWhenReceiptIsDrainedWhileSchedulingIsPending() {
		startApp()
		syncApp()
		let nse = makeExtension()
		let appStorage = mobileMessagingInstance.sharedNotificationExtensionStorage!
		var scheduledIds = [String]()
		let delegate = MessageHandlingDelegateMock()
		delegate.willScheduleLocalNotification = { scheduledIds.append($0.messageId) }
		MobileMessaging.messageHandlingDelegate = delegate
		defer { MobileMessaging.messageHandlingDelegate = nil }

		let messageStorage = ReceiptSavingMessageStorageStub(onInsert: { messages in
			guard messages.contains(where: { $0.messageId == "m1" }) else { return }
			let reported = DispatchSemaphore(value: 0)
			Task { await nse.reportDelivery(for: self.nseMessage("m1")); reported.signal() }
			reported.wait()
			_ = appStorage.drainMessages()
		})
		mobileMessagingInstance.messageStorages[MessageStorageKind.messages.rawValue] = MessageStorageQueuedAdapter.makeMessagesStoragaAdapter(storage: messageStorage)
		serverPayloads = { [apnsNormalMessagePayload("m1")] }
		onServerFetch = {
			self.onServerFetch = {}
			self.serverPayloads = { [] }
		}

		receiveSilentPush()

		XCTAssertFalse(scheduledIds.contains("m1"))
	}

	// The final check right before UNUserNotificationCenter.add, after the attachment download, sees a drained receipt.
	func testFinalSchedulingCheckSeesReceiptDrainedDuringScheduling() {
		startApp()
		let nse = makeExtension()
		let appStorage = mobileMessagingInstance.sharedNotificationExtensionStorage!
		var addedRequestIds = [String]()
		let originalAdd = LocalNotifications.addNotificationRequest
		LocalNotifications.addNotificationRequest = { request, completion in
			addedRequestIds.append(request.identifier)
			completion(nil)
		}
		defer { LocalNotifications.addNotificationRequest = originalAdd }

		finish(Task { await nse.reportDelivery(for: self.nseMessage("m1")) })
		_ = appStorage.drainMessages()

		weak let scheduled = expectation(description: "scheduling decision made")
		let message = MM_MTMessage(payload: apnsNormalMessagePayload("m1"), deliveryMethod: .pull, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false)!
		LocalNotifications.scheduleUserNotification(with: message, isPresentedByExtension: {
			appStorage.messageIdsHandledByExtension().contains("m1")
		}, completion: { scheduled?.fulfill() })
		waitForExpectations(timeout: 5) { _ in }

		XCTAssert(addedRequestIds.isEmpty)
	}

	// Reviewer: the same message delivered to the extension twice must be reported once.
	func testSequentialDuplicateExtensionDeliveriesReportOnce() {
		startApp()
		let nse = makeExtension()

		finish(Task { await nse.reportDelivery(for: self.nseMessage("m1")) })
		finish(Task { await nse.reportDelivery(for: self.nseMessage("m1")) })

		XCTAssertEqual(GatedDeliveryReportURLProtocol.reportedIds, ["m1"])
	}

	func testOverlappingDuplicateExtensionDeliveriesReportOnce() {
		startApp()
		GatedDeliveryReportURLProtocol.reset(holdRequests: true)
		let nse = makeExtension()

		let first = startExtensionReport(nse, messageId: "m1")
		let second = Task { await nse.reportDelivery(for: self.nseMessage("m1")) }
		finish(second) // must not wait for the held request
		GatedDeliveryReportURLProtocol.releaseOneRequest()
		GatedDeliveryReportURLProtocol.releaseOneRequest()
		finish(first)

		XCTAssertEqual(GatedDeliveryReportURLProtocol.reportedIds, ["m1"])
	}

	func testDuplicateDeliveryAfterFailedExtensionReportRetries() {
		startApp()
		let nse = makeExtension()

		GatedDeliveryReportURLProtocol.failRequests = true
		finish(Task { await nse.reportDelivery(for: self.nseMessage("m1")) })
		GatedDeliveryReportURLProtocol.failRequests = false
		finish(Task { await nse.reportDelivery(for: self.nseMessage("m1")) })

		XCTAssertEqual(GatedDeliveryReportURLProtocol.reportedIds, ["m1"])
	}
}

private class EmptyNotificationCenterStorage: UserNotificationCenterStorage {
	func getDeliveredMessages(completionHandler: @escaping ([MM_MTMessage]) -> Swift.Void) {
		completionHandler([])
	}
}
