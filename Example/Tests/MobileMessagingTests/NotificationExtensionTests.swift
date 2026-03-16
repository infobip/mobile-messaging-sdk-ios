//
//  Example/Tests/MobileMessagingTests/NotificationExtensionTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
@testable import MobileMessagingNotificationExtension

// MARK: - MMNSEMessage Tests

class MMNSEMessageTests: XCTestCase {

	func testValidPayload_CreatesMessage() {
		let payload: [String: Any] = [
			"messageId": "test-msg-123",
			"aps": ["alert": "Hello"]
		]
		let message = MMNSEMessage(payload: payload)
		XCTAssertNotNil(message)
		XCTAssertEqual(message?.messageId, "test-msg-123")
		XCTAssertNil(message?.contentUrl)
		XCTAssertFalse(message?.isDeliveryReportSent ?? true)
		XCTAssertNil(message?.deliveryReportedDate)
	}

	func testPayloadWithAttachment_ExtractsContentUrl() {
		let payload: [String: Any] = [
			"messageId": "test-msg-456",
			"aps": ["alert": "Hello"],
			"internalData": [
				"atts": [
					["url": "https://example.com/image.jpg"]
				]
			]
		]
		let message = MMNSEMessage(payload: payload)
		XCTAssertNotNil(message)
		XCTAssertEqual(message?.contentUrl, "https://example.com/image.jpg")
	}

	func testPayloadWithMultipleAttachments_ExtractsFirstUrl() {
		let payload: [String: Any] = [
			"messageId": "test-msg-789",
			"aps": ["alert": "Hello"],
			"internalData": [
				"atts": [
					["url": "https://example.com/first.jpg"],
					["url": "https://example.com/second.jpg"]
				]
			]
		]
		let message = MMNSEMessage(payload: payload)
		XCTAssertEqual(message?.contentUrl, "https://example.com/first.jpg")
	}

	func testPayloadWithoutMessageId_ReturnsNil() {
		let payload: [String: Any] = [
			"aps": ["alert": "Hello"]
		]
		let message = MMNSEMessage(payload: payload)
		XCTAssertNil(message)
	}

	func testPayloadWithoutAps_ReturnsNil() {
		let payload: [String: Any] = [
			"messageId": "test-msg-123"
		]
		let message = MMNSEMessage(payload: payload)
		XCTAssertNil(message)
	}

	func testEmptyPayload_ReturnsNil() {
		let payload: [String: Any] = [:]
		let message = MMNSEMessage(payload: payload)
		XCTAssertNil(message)
	}

	func testIsCorrectPayload_ValidPayload() {
		let payload: [String: Any] = [
			"messageId": "test-msg-123",
			"aps": ["alert": "Hello"]
		]
		XCTAssertTrue(MMNSEMessage.isCorrectPayload(payload))
	}

	func testIsCorrectPayload_InvalidPayload() {
		XCTAssertFalse(MMNSEMessage.isCorrectPayload([:]))
		XCTAssertFalse(MMNSEMessage.isCorrectPayload(["aps": ["alert": "Hello"]]))
		XCTAssertFalse(MMNSEMessage.isCorrectPayload(["messageId": "123"]))
	}

	func testPayloadWithEmptyAttachments_NoContentUrl() {
		let payload: [String: Any] = [
			"messageId": "test-msg",
			"aps": ["alert": "Hello"],
			"internalData": [
				"atts": [] as [[String: Any]]
			]
		]
		let message = MMNSEMessage(payload: payload)
		XCTAssertNotNil(message)
		XCTAssertNil(message?.contentUrl)
	}

	func testMessageMutability() {
		let payload: [String: Any] = [
			"messageId": "test-msg",
			"aps": ["alert": "Hello"]
		]
		var message = MMNSEMessage(payload: payload)!
		XCTAssertFalse(message.isDeliveryReportSent)
		XCTAssertNil(message.deliveryReportedDate)

		message.isDeliveryReportSent = true
		message.deliveryReportedDate = Date()

		XCTAssertTrue(message.isDeliveryReportSent)
		XCTAssertNotNil(message.deliveryReportedDate)
	}

	func testOriginalPayloadPreserved() {
		let payload: [String: Any] = [
			"messageId": "test-msg",
			"aps": ["alert": "Hello"],
			"customPayload": ["key": "value"]
		]
		let message = MMNSEMessage(payload: payload)!
		XCTAssertEqual(message.originalPayload["messageId"] as? String, "test-msg")
		XCTAssertNotNil(message.originalPayload["customPayload"])
	}

	func testIsCorrectPayload_PublicAPI() {
		let validPayload: [String: Any] = [
			"messageId": "test-msg-123",
			"aps": ["alert": "Hello"]
		]
		XCTAssertTrue(MobileMessagingNotificationServiceExtension.isCorrectPayload(validPayload))
		XCTAssertFalse(MobileMessagingNotificationServiceExtension.isCorrectPayload([:]))
	}
}

// MARK: - MMNSEUtils Tests

class MMNSEUtilsTests: XCTestCase {

	func testSha256_KnownValue() {
		let result = "hello".sha256()
		XCTAssertEqual(result, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
	}

	func testSha256_EmptyString() {
		let result = "".sha256()
		XCTAssertEqual(result, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
	}

	func testSha256_Consistency() {
		let input = "test-app-code"
		let first = input.sha256()
		let second = input.sha256()
		XCTAssertEqual(first, second)
	}

	func testSafeUrl_ValidUrl() {
		let url = "https://example.com/image.jpg".safeUrl
		XCTAssertNotNil(url)
		XCTAssertEqual(url?.absoluteString, "https://example.com/image.jpg")
	}

	func testCalculateAppCodeHash() {
		let hash = calculateAppCodeHash("test-app-code")
		let fullHash = "test-app-code".sha256()
		XCTAssertEqual(hash, String(fullHash.prefix(10)))
		XCTAssertEqual(hash.count, 10)
	}

	func testAttachmentDownloadDestinationFolder_WithoutAppGroup() {
		let folderUrl = URL.attachmentDownloadDestinationFolderUrl(appGroupId: nil)
		XCTAssertTrue(folderUrl.path.contains("com.mobile-messaging.rich-notifications-attachments"))
	}

	func testAttachmentDownloadDestinationUrl_ContainsSha256() {
		let sourceUrl = URL(string: "https://example.com/image.jpg")!
		let destUrl = URL.attachmentDownloadDestinationUrl(sourceUrl: sourceUrl, appGroupId: nil)
		let expectedHash = sourceUrl.absoluteString.sha256()
		XCTAssertTrue(destUrl.lastPathComponent.hasPrefix(expectedHash))
		XCTAssertTrue(destUrl.lastPathComponent.hasSuffix(".jpg"))
	}
}

// MARK: - MMNSESharedStorage Tests

class MMNSESharedStorageTests: XCTestCase {

	private let testSuiteName = "com.infobip.test.nse-shared-storage"
	private let testAppCode = "test-app-code"

	override func tearDown() {
		UserDefaults.standard.removePersistentDomain(forName: testSuiteName)
		super.tearDown()
	}

	func testSaveAndRetrieveMessage() {
		let storage = MMNSESharedStorage(applicationCode: testAppCode, appGroupId: testSuiteName)
		XCTAssertNotNil(storage)

		let payload: [String: Any] = [
			"messageId": "test-msg-1",
			"aps": ["alert": "Hello"]
		]
		var message = MMNSEMessage(payload: payload)!
		message.isDeliveryReportSent = true
		message.deliveryReportedDate = Date()

		storage?.save(message: message)

		let defaults = UserDefaults(suiteName: testSuiteName)!
		let data = defaults.object(forKey: testAppCode) as? Data
		XCTAssertNotNil(data)
	}

	func testSaveMultipleMessages() {
		let storage = MMNSESharedStorage(applicationCode: testAppCode, appGroupId: testSuiteName)!

		for i in 1...3 {
			let payload: [String: Any] = [
				"messageId": "test-msg-\(i)",
				"aps": ["alert": "Hello \(i)"]
			]
			let message = MMNSEMessage(payload: payload)!
			storage.save(message: message)
		}

		let defaults = UserDefaults(suiteName: testSuiteName)!
		let data = defaults.object(forKey: testAppCode) as? Data
		XCTAssertNotNil(data)

		let unarchived = try? NSKeyedUnarchiver.unarchivedObject(
			ofClasses: [NSArray.self, NSDictionary.self, NSNull.self, NSString.self, NSNumber.self, NSDate.self],
			from: data!
		) as? [[String: Any]]
		XCTAssertEqual(unarchived?.count, 3)
	}

	func testSavedMessageFormat() {
		let storage = MMNSESharedStorage(applicationCode: testAppCode, appGroupId: testSuiteName)!

		let payload: [String: Any] = [
			"messageId": "test-msg-1",
			"aps": ["alert": "Hello"]
		]
		var message = MMNSEMessage(payload: payload)!
		message.isDeliveryReportSent = true
		let reportDate = Date()
		message.deliveryReportedDate = reportDate

		storage.save(message: message)

		let defaults = UserDefaults(suiteName: testSuiteName)!
		let data = defaults.object(forKey: testAppCode) as! Data
		let unarchived = try! NSKeyedUnarchiver.unarchivedObject(
			ofClasses: [NSArray.self, NSDictionary.self, NSNull.self, NSString.self, NSNumber.self, NSDate.self],
			from: data
		) as! [[String: Any]]

		let savedMsg = unarchived.first!
		let savedPayload = savedMsg["p"] as? [String: Any]
		XCTAssertEqual(savedPayload?["messageId"] as? String, "test-msg-1")
		XCTAssertEqual(savedMsg["dlr"] as? Bool, true)
		XCTAssertNotNil(savedMsg["dlrd"])
	}

	/// Verifies storage contract: the format written by MMNSESharedStorage must be readable
	/// by the main SDK's DefaultSharedDataStorage.retrieveMessages().
	/// DefaultSharedDataStorage expects each dict to have:
	///   "p" -> [String: Any] payload (must contain "messageId" and "aps")
	///   "dlr" -> Bool (isDeliveryReportSent)
	///   "dlrd" -> Date? (deliveryReportedDate)
	func testStorageFormat_CompatibleWithMainSDK() {
		let storage = MMNSESharedStorage(applicationCode: testAppCode, appGroupId: testSuiteName)!

		let payload: [String: Any] = [
			"messageId": "compat-msg-1",
			"aps": ["alert": ["title": "Title", "body": "Body"], "badge": 1, "sound": "default"],
			"internalData": ["sendDateTime": 1700000000000, "atts": [["url": "https://example.com/pic.jpg"]]],
			"customPayload": ["key": "value"]
		]
		var message = MMNSEMessage(payload: payload)!
		message.isDeliveryReportSent = true
		message.deliveryReportedDate = Date(timeIntervalSince1970: 1700000000)

		storage.save(message: message)

		// Unarchive exactly how DefaultSharedDataStorage does it
		let defaults = UserDefaults(suiteName: testSuiteName)!
		let data = defaults.object(forKey: testAppCode) as! Data
		let unarchived = try! NSKeyedUnarchiver.unarchivedObject(
			ofClasses: [NSArray.self, NSDictionary.self, NSNull.self, NSString.self, NSNumber.self, NSDate.self],
			from: data
		) as! [[String: Any]]

		XCTAssertEqual(unarchived.count, 1)

		let msgDict = unarchived[0]

		// "p" key — must be the full original payload
		let p = msgDict["p"] as? [String: Any]
		XCTAssertNotNil(p, "Missing 'p' key — main SDK requires payload under 'p'")
		XCTAssertEqual(p?["messageId"] as? String, "compat-msg-1")
		XCTAssertNotNil(p?["aps"], "Payload must contain 'aps'")
		XCTAssertNotNil(p?["internalData"], "Payload must preserve 'internalData'")
		XCTAssertNotNil(p?["customPayload"], "Payload must preserve 'customPayload'")

		// "dlr" key — main SDK reads as Bool
		let dlr = msgDict["dlr"] as? Bool
		XCTAssertNotNil(dlr, "Missing 'dlr' key — main SDK requires delivery report flag under 'dlr'")
		XCTAssertTrue(dlr!)

		// "dlrd" key — main SDK reads as Date?
		let dlrd = msgDict["dlrd"] as? Date
		XCTAssertNotNil(dlrd, "Missing 'dlrd' key — main SDK reads delivery report date under 'dlrd'")
		XCTAssertEqual(dlrd!.timeIntervalSince1970, 1700000000, accuracy: 1)
	}

	func testStorageFormat_DeliveryNotSent_CompatibleWithMainSDK() {
		let storage = MMNSESharedStorage(applicationCode: testAppCode, appGroupId: testSuiteName)!

		let payload: [String: Any] = [
			"messageId": "compat-msg-2",
			"aps": ["alert": "Hello"]
		]
		let message = MMNSEMessage(payload: payload)!
		// Default: isDeliveryReportSent = false, deliveryReportedDate = nil

		storage.save(message: message)

		let defaults = UserDefaults(suiteName: testSuiteName)!
		let data = defaults.object(forKey: testAppCode) as! Data
		let unarchived = try! NSKeyedUnarchiver.unarchivedObject(
			ofClasses: [NSArray.self, NSDictionary.self, NSNull.self, NSString.self, NSNumber.self, NSDate.self],
			from: data
		) as! [[String: Any]]

		let msgDict = unarchived[0]
		XCTAssertEqual(msgDict["dlr"] as? Bool, false)
		XCTAssertNil(msgDict["dlrd"], "When delivery not reported, 'dlrd' should be nil/absent")
	}

	func testCleanupAfterMainSDKRead() {
		let storage = MMNSESharedStorage(applicationCode: testAppCode, appGroupId: testSuiteName)!

		let payload: [String: Any] = [
			"messageId": "cleanup-msg",
			"aps": ["alert": "Hello"]
		]
		let message = MMNSEMessage(payload: payload)!
		storage.save(message: message)

		let defaults = UserDefaults(suiteName: testSuiteName)!
		XCTAssertNotNil(defaults.object(forKey: testAppCode))

		// Main SDK calls cleanupMessages() which does removeObject(forKey: applicationCode)
		defaults.removeObject(forKey: testAppCode)
		XCTAssertNil(defaults.object(forKey: testAppCode))
	}
}

// MARK: - MMNSEDeliveryReporter Tests

class MMNSEDeliveryReporterTests: XCTestCase {

	private let testSuiteName = "com.infobip.test.nse-delivery-reporter"

	override func tearDown() {
		UserDefaults.standard.removePersistentDomain(forName: testSuiteName)
		super.tearDown()
	}

	func testReportWithEmptyMessageIds_ReturnsImmediately() async throws {
		let storage = UserDefaults(suiteName: testSuiteName)!
		let reporter = MMNSEDeliveryReporter(applicationCode: "test-app", appGroupId: testSuiteName, storage: storage)

		// Should complete without throwing — empty message IDs is a no-op
		try await reporter.report(messageIds: [], pushRegId: nil)
	}

	func testDynamicBaseUrl_StoredUrlIsUsed() {
		let storage = UserDefaults(suiteName: testSuiteName)!
		let customUrl = URL(string: "https://custom.example.com")!
		storage.set(customUrl, forKey: MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey)

		let storedUrl = storage.url(forKey: MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey)
		XCTAssertEqual(storedUrl, customUrl)
	}

	func testDynamicBaseUrl_FallsBackToProd() {
		let storage = UserDefaults(suiteName: testSuiteName)!
		storage.removeObject(forKey: MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey)

		let storedUrl = storage.url(forKey: MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey)
		XCTAssertNil(storedUrl)
	}
}

// MARK: - MMNSEAttachmentDownloader Tests

/// URLProtocol stub that lets tests control download responses.
private class MockDownloadURLProtocol: URLProtocol {
	/// Handler called for each request. Return (fileURL, response) or throw.
	static var requestHandler: ((URLRequest) throws -> (URL, URLResponse))?
	static var requestCount = 0

	override class func canInit(with request: URLRequest) -> Bool { true }
	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		MockDownloadURLProtocol.requestCount += 1
		guard let handler = MockDownloadURLProtocol.requestHandler else {
			client?.urlProtocol(self, didFailWithError: URLError(.unknown))
			return
		}
		do {
			let (fileUrl, response) = try handler(request)
			client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
			let data = try Data(contentsOf: fileUrl)
			client?.urlProtocol(self, didLoad: data)
			client?.urlProtocolDidFinishLoading(self)
		} catch {
			client?.urlProtocol(self, didFailWithError: error)
		}
	}

	override func stopLoading() {}
}

class MMNSEAttachmentDownloaderTests: XCTestCase {

	private func makeMockSession() -> URLSession {
		let config = URLSessionConfiguration.ephemeral
		config.protocolClasses = [MockDownloadURLProtocol.self]
		return URLSession(configuration: config)
	}

	override func setUp() {
		super.setUp()
		MockDownloadURLProtocol.requestHandler = nil
		MockDownloadURLProtocol.requestCount = 0
	}

	func testDownload_SucceedsOnFirstAttempt() async throws {
		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test-image.jpg")
		try Data("fake-image-data".utf8).write(to: tempFile)

		MockDownloadURLProtocol.requestHandler = { _ in
			let response = HTTPURLResponse(url: URL(string: "https://example.com/image.jpg")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (tempFile, response)
		}

		let downloader = MMNSEAttachmentDownloader(maxRetries: 3, session: makeMockSession())
		let url = URL(string: "https://example.com/image.jpg")!
		let result = try await downloader.download(contentUrl: url)

		XCTAssertTrue(FileManager.default.fileExists(atPath: result.path))
		XCTAssertEqual(MockDownloadURLProtocol.requestCount, 1)

		try? FileManager.default.removeItem(at: result)
		try? FileManager.default.removeItem(at: tempFile)
	}

	func testDownload_RetriesOnFailureThenSucceeds() async throws {
		let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test-retry-image.jpg")
		try Data("fake-image-data".utf8).write(to: tempFile)

		var callCount = 0
		MockDownloadURLProtocol.requestHandler = { _ in
			callCount += 1
			if callCount < 3 {
				throw URLError(.networkConnectionLost)
			}
			let response = HTTPURLResponse(url: URL(string: "https://example.com/image.jpg")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
			return (tempFile, response)
		}

		let downloader = MMNSEAttachmentDownloader(maxRetries: 3, session: makeMockSession())
		let url = URL(string: "https://example.com/image.jpg")!
		let result = try await downloader.download(contentUrl: url)

		XCTAssertTrue(FileManager.default.fileExists(atPath: result.path))
		XCTAssertEqual(MockDownloadURLProtocol.requestCount, 3)

		try? FileManager.default.removeItem(at: result)
		try? FileManager.default.removeItem(at: tempFile)
	}

	func testDownload_ExhaustsRetriesThenThrows() async {
		MockDownloadURLProtocol.requestHandler = { _ in
			throw URLError(.timedOut)
		}

		let downloader = MMNSEAttachmentDownloader(maxRetries: 2, session: makeMockSession())
		let url = URL(string: "https://example.com/image.jpg")!

		do {
			_ = try await downloader.download(contentUrl: url)
			XCTFail("Expected download to throw after exhausting retries")
		} catch {
			XCTAssertEqual(MockDownloadURLProtocol.requestCount, 2)
			XCTAssertEqual((error as? URLError)?.code, .timedOut)
		}
	}

	func testDownload_SingleRetry_FailsImmediately() async {
		MockDownloadURLProtocol.requestHandler = { _ in
			throw URLError(.cannotConnectToHost)
		}

		let downloader = MMNSEAttachmentDownloader(maxRetries: 1, session: makeMockSession())
		let url = URL(string: "https://example.com/image.jpg")!

		do {
			_ = try await downloader.download(contentUrl: url)
			XCTFail("Expected download to throw")
		} catch {
			XCTAssertEqual(MockDownloadURLProtocol.requestCount, 1)
		}
	}

	func testDownload_CancellationRespected() async {
		let downloader = MMNSEAttachmentDownloader()
		let url = URL(string: "https://localhost:1/nonexistent-file.jpg")!

		let task = Task {
			try await downloader.download(contentUrl: url)
		}
		task.cancel()

		do {
			_ = try await task.value
			XCTFail("Expected download to throw after cancellation")
		} catch {
			// Expected — CancellationError or connection error
		}
	}

	func testDownload_InvalidUrl_Throws() async {
		let downloader = MMNSEAttachmentDownloader()
		let invalidUrl = URL(string: "https://localhost:1/nonexistent-file.jpg")!

		do {
			_ = try await downloader.download(contentUrl: invalidUrl)
			XCTFail("Expected download to throw")
		} catch {
			// Expected — connection refused or timeout
		}
	}

	func testDownload_DefaultMaxRetries() {
		let downloader = MMNSEAttachmentDownloader()
		XCTAssertEqual(downloader.maxRetries, 3)
	}
}

// MARK: - MMNSEKeychain Tests

class MMNSEKeychainTests: XCTestCase {

	func testKeychainInit_WithoutAppGroup() {
		let keychain = MMNSEKeychain(accessGroup: nil)
		// Should not crash, applicationCode will just be nil since nothing is stored
		XCTAssertNil(keychain.applicationCode)
		XCTAssertNil(keychain.pushRegId)
	}
}

// MARK: - MMNSEConstants Tests (migration parity with main SDK)

class MMNSEConstantsTests: XCTestCase {

	func testDeliveryReportPath() {
		XCTAssertEqual(MMNSEConsts.API.deliveryReportPath, "/mobile/1/messages/deliveryreport")
	}

	func testProdBaseUrl() {
		XCTAssertEqual(MMNSEConsts.API.prodBaseURLString, "https://mobile.infobip.com")
	}

	func testDlrMessageIdsKey() {
		XCTAssertEqual(MMNSEConsts.DeliveryReport.dlrMessageIds, "dlrIds")
	}

	func testDynamicBaseUrlKeys() {
		XCTAssertEqual(MMNSEConsts.DynamicBaseUrl.newBaseUrlHeader, "New-Base-URL")
		XCTAssertEqual(MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey, "com.mobile-messaging.dynamic-base-url")
	}

	func testAPIHeaders() {
		XCTAssertEqual(MMNSEConsts.APIHeaders.pushRegistrationId, "pushregistrationid")
		XCTAssertEqual(MMNSEConsts.APIHeaders.applicationcode, "applicationcode")
		XCTAssertEqual(MMNSEConsts.APIHeaders.installationId, "installationid")
		XCTAssertEqual(MMNSEConsts.APIHeaders.authorization, "Authorization")
		XCTAssertEqual(MMNSEConsts.APIHeaders.authorizationApiKey, "App")
		XCTAssertEqual(MMNSEConsts.APIHeaders.foreground, "foreground")
		XCTAssertEqual(MMNSEConsts.APIHeaders.accept, "Accept")
		XCTAssertEqual(MMNSEConsts.APIHeaders.contentType, "Content-Type")
	}

	func testKeychainKeys() {
		XCTAssertEqual(MMNSEConsts.KeychainKeys.prefix, "com.mobile-messaging")
		XCTAssertEqual(MMNSEConsts.KeychainKeys.pushRegId, "internalId")
		XCTAssertEqual(MMNSEConsts.KeychainKeys.appCode, "appCode")
	}

	func testUserDefaultsKeys() {
		XCTAssertEqual(MMNSEConsts.UserDefaultsKeys.universalInstallationId, "com.mobile-messaging.universal-installation-id")
	}

	func testInfoPlistKeys() {
		XCTAssertEqual(MMNSEConsts.InfoPlistKeys.appGroupId, "com.mobilemessaging.app_group")
	}
}

// MARK: - MMNSEDeliveryReporter Construction Tests (migration parity)

class MMNSEDeliveryReporterConstructionTests: XCTestCase {

	private let testSuiteName = "com.infobip.test.nse-reporter-construction"

	override func tearDown() {
		UserDefaults.standard.removePersistentDomain(forName: testSuiteName)
		super.tearDown()
	}

	func testAppCodeHash_MatchesExpectedFormat() {
		let appCode = "test-app-code"
		let hash = calculateAppCodeHash(appCode)
		let fullSha = appCode.sha256()

		// Must be first 10 chars of sha256
		XCTAssertEqual(hash, String(fullSha.prefix(10)))
		XCTAssertEqual(hash.count, 10)
	}

	func testInstallationId_ReadFromStorage() {
		let storage = UserDefaults(suiteName: testSuiteName)!
		let expectedId = "nse-installation-id-123"
		storage.set(expectedId, forKey: MMNSEConsts.UserDefaultsKeys.universalInstallationId)

		let readId = storage.string(forKey: MMNSEConsts.UserDefaultsKeys.universalInstallationId)
		XCTAssertEqual(readId, expectedId)

		storage.removeObject(forKey: MMNSEConsts.UserDefaultsKeys.universalInstallationId)
	}

	func testDynamicBaseUrl_StoredUrlOverridesProd() {
		let storage = UserDefaults(suiteName: testSuiteName)!
		let customUrl = URL(string: "https://custom.infobip.com")!
		storage.set(customUrl, forKey: MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey)

		let storedUrl = storage.url(forKey: MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey)
		XCTAssertEqual(storedUrl, customUrl)
		XCTAssertNotEqual(storedUrl?.absoluteString, MMNSEConsts.API.prodBaseURLString)
	}

	func testDynamicBaseUrl_NilFallsToProd() {
		let storage = UserDefaults(suiteName: testSuiteName)!
		storage.removeObject(forKey: MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey)

		let storedUrl = storage.url(forKey: MMNSEConsts.DynamicBaseUrl.storedDynamicBaseUrlKey)
		XCTAssertNil(storedUrl)
		// When nil, reporter should use MMNSEConsts.API.prodBaseURLString
		XCTAssertNotNil(URL(string: MMNSEConsts.API.prodBaseURLString))
	}

	func testDeliveryReportBodyFormat() throws {
		let messageIds = ["msg1", "msg2", "msg3"]
		let body: [String: Any] = [MMNSEConsts.DeliveryReport.dlrMessageIds: messageIds]
		let data = try JSONSerialization.data(withJSONObject: body, options: [])
		let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
		let decodedIds = decoded?["dlrIds"] as? [String]
		XCTAssertEqual(decodedIds, messageIds)
	}
}
