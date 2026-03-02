// 
//  Example/Tests/MobileMessagingTests/DepersonalizeTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
import Foundation
@testable import MobileMessaging

let successfulDepersonalizeApiMock = { () -> RemoteAPIProviderStub in
	let ret = RemoteAPIProviderStub()
	ret.depersonalizeClosure = { _, _, _ -> DepersonalizeResult in
		return DepersonalizeResult.Success(EmptyResponse(json: JSON.parse(""))!)
	}

	ret.personalizeClosure = { _, _, _, _ -> PersonalizeResult in
		return PersonalizeResult.Success(MMUser(json: JSON.parse(""))!)
	}
	ret.syncMessagesClosure = { _, _, _ -> MessagesSyncResult in
		return MessagesSyncResult.Failure(retryableError)
	}
	return ret
}()

let failedDepersonalizeApiMock = { () -> RemoteAPIProviderStub in
	let ret = RemoteAPIProviderStub()
	ret.depersonalizeClosure = { _, _, _ -> DepersonalizeResult in
		return DepersonalizeResult.Failure(retryableError)
	}

	ret.personalizeClosure = { _, _, _, _ -> PersonalizeResult in
		return PersonalizeResult.Failure(retryableError)
	}

	ret.syncMessagesClosure = { _, _, _ -> MessagesSyncResult in
		return MessagesSyncResult.Failure(retryableError)
	}
	return ret
}()


class DepersonalizeTests: MMTestCase {
	//MARK: - Helper Methods
	private func prepareUserData() {
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let user = MobileMessaging.getUser()!
		user.firstName = "Darth"
		user.customAttributes = ["bootsize": 9.5 as NSNumber]
		user.archiveDirty()

		XCTAssertNotNil(MobileMessaging.getInstallation()?.pushRegistrationId)
		XCTAssertEqual(MobileMessaging.getUser()!.firstName, "Darth")
		XCTAssertEqual(MobileMessaging.getUser()!.customAttributes!["bootsize"] as? NSNumber, 9.5)
	}

	private func performFailedDepersonalizeCase() async throws {
		MobileMessaging.sharedInstance?.remoteApiProvider = failedDepersonalizeApiMock
		do {
			let s = try await MobileMessaging.depersonalize()
			XCTFail("Should have thrown error, got status: \(s)")
		} catch {
			XCTAssertEqual(MMSuccessPending.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
		}
	}

	private func performFailedDepersonalizeCaseWithOverlimit() async throws {
		MobileMessaging.sharedInstance?.remoteApiProvider = failedDepersonalizeApiMock
		do {
			let s = try await MobileMessaging.depersonalize()
			XCTFail("Should have thrown error, got status: \(s)")
		} catch {
			XCTAssertEqual(MMSuccessPending.undefined, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
		}
	}

	private func performSuccessfullDepersonalizeCase() async throws {
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
		let s = try await MobileMessaging.depersonalize()
		XCTAssertEqual(MMSuccessPending.success, s)
	}


	func testThatUserDataCleanedUpAfterDepersonalize() async throws {
		MMTestCase.startWithCorrectApplicationCode()
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let user = MobileMessaging.getUser()!
		user.firstName = "Darth"
		user.customAttributes = ["bootsize": 9.5 as NSNumber]
		user.archiveDirty()

		XCTAssertEqual(mobileMessagingInstance.internalData().currentDepersonalizationStatus, MMSuccessPending.undefined)
		XCTAssertEqual(MobileMessaging.getUser()!.firstName, "Darth")
		XCTAssertEqual(MobileMessaging.getUser()!.customAttributes!["bootsize"] as? NSNumber, 9.5)

		let status = try await MobileMessaging.depersonalize()
		XCTAssertEqual(status, MMSuccessPending.undefined)

		// assert there is no user data
		let userAfter = MobileMessaging.getUser()!
		XCTAssertNil(userAfter.firstName)
		XCTAssertNil(userAfter.customAttributes?["bootsize"])
	}

	func testThatInstallationPrimaryFlagResetAfterDepersonalize() async throws {
		MMTestCase.startWithCorrectApplicationCode()
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let i = MobileMessaging.getInstallation()!
		i.isPrimaryDevice = true
		i.archiveAll()

		let status = try await MobileMessaging.depersonalize()
		XCTAssertEqual(status, MMSuccessPending.undefined)

		let iAfter = MobileMessaging.getInstallation()!
		XCTAssertFalse(iAfter.isPrimaryDevice)
	}

	func testThatDefaultMessageStorageCleanedUpAfterDepersonalize() async throws {
		MMTestCase.startWithCorrectApplicationCode()
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
		mobileMessagingInstance.pushRegistrationId = "rand"

		let sentMessagesCount: Int = 5

		_ = mobileMessagingInstance.withDefaultMessageStorage()
		MobileMessaging.defaultMessageStorage?.start()

		XCTAssertEqual(0, MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")

		// Send pushes and process them sequentially
		for _ in 0..<sentMessagesCount {
			let userInfo = apnsNormalMessagePayload(UUID().uuidString)
			await withCheckedContinuation { continuation in
				self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: userInfo) { _ in
					continuation.resume()
				}
			}
		}

		let messages = await MobileMessaging.defaultMessageStorage!.findAllMessages()
		XCTAssertEqual(sentMessagesCount, messages?.count)
		XCTAssertEqual(sentMessagesCount, MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")

		_ = try await MobileMessaging.depersonalize()

		XCTAssertEqual(.undefined, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
		// assert there is not any message in message storage
		let messagesAfter = Message.MM_findAllWithPredicate(nil, context: MobileMessaging.defaultMessageStorage!.context!)
		XCTAssertTrue(messagesAfter == nil || messagesAfter?.isEmpty ?? true)
		// internal message storage must be cleaned up
		XCTAssertEqual(sentMessagesCount, MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")
	}

	func testThatAfterFailedDepersonalize_DepersonalizeStatusIsPending() async throws {
		MMTestCase.startWithCorrectApplicationCode()
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock

		prepareUserData()
		try await performFailedDepersonalizeCase()

		XCTAssertEqual(.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
		XCTAssertFalse(self.mobileMessagingInstance.messageHandler.isRunning)
		XCTAssertNil(MobileMessaging.getUser()!.firstName)
		XCTAssertNil(MobileMessaging.getUser()!.customAttributes?["bootsize"])
	}

	func testThatAfterSuccessfulReDepersonalize_DepersonalizeStatusIsSuccess() async throws {
		MMTestCase.startWithCorrectApplicationCode()
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock

		prepareUserData()
		try await performFailedDepersonalizeCase()
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		try await performSuccessfullDepersonalizeCase()

		XCTAssertEqual(.success, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
		XCTAssertTrue(self.mobileMessagingInstance.messageHandler.isRunning)
		XCTAssertNil(MobileMessaging.getUser()!.firstName)
		XCTAssertNil(MobileMessaging.getUser()!.customAttributes?["bootsize"])
	}

	func testThatAfterFailedDepersonalizeLimitExceeded_DepersonalizeStatusBecomesUndefined() async throws {
		MMTestCase.startWithCorrectApplicationCode()
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock

		DepersonalizationConsts.failuresNumberLimit = 2 // limit of failed attempts
		prepareUserData()
		try await performFailedDepersonalizeCase() // 1st attempt
		try await performFailedDepersonalizeCaseWithOverlimit() // 2nd attempt

		XCTAssertEqual(.undefined, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
		XCTAssertTrue(self.mobileMessagingInstance.messageHandler.isRunning)
		XCTAssertNil(MobileMessaging.getUser()!.firstName)
		XCTAssertNil(MobileMessaging.getUser()!.customAttributes?["bootsize"])
	}

	func testThatPendingDepersonalizeKeptBetweenRestarts() async throws {
		MMTestCase.startWithCorrectApplicationCode()
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
		prepareUserData()

		try await performFailedDepersonalizeCase()
		XCTAssertEqual(.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
		MobileMessaging.sharedInstance?.doStop(nil)

		MMTestCase.startWithCorrectApplicationCode()

		XCTAssertEqual(.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
		XCTAssertFalse(self.mobileMessagingInstance.messageHandler.isRunning)
		XCTAssertNil(MobileMessaging.getUser()!.firstName)
		XCTAssertNil(MobileMessaging.getUser()!.customAttributes?["bootsize"])
	}

	func testThatAPNSUnregistersOnFailedDepersonalize() async throws {
		MMTestCase.startWithCorrectApplicationCode()
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock

		var unregisterCalled: Bool = false
		let mock = ApnsRegistrationManagerMock(mmContext: mobileMessagingInstance)
		mock.unregisterCalled = {
			unregisterCalled = true
		}
		mobileMessagingInstance.apnsRegistrationManager = mock

		prepareUserData()
		try await performFailedDepersonalizeCase()

		XCTAssertTrue(unregisterCalled)
	}

	func testThatAPNSRegistersOnReDepersonalize() async throws {
		MMTestCase.startWithCorrectApplicationCode()
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock

		var unregisterCalled: Bool = false
		var registerCalled: Bool = false
		let mock = ApnsRegistrationManagerMock(mmContext: mobileMessagingInstance)
		mock.unregisterCalled = {
			unregisterCalled = true
		}
		mock.registerCalled = {
			registerCalled = true
		}

		prepareUserData()
		mobileMessagingInstance.apnsRegistrationManager = mock
		try await performFailedDepersonalizeCase()
		try await performSuccessfullDepersonalizeCase()

		XCTAssertTrue(unregisterCalled)
		XCTAssertTrue(registerCalled)
	}

	func testDepersonalizeHasHigherPriorityThanUserDataOperations() async throws {
		MMTestCase.startWithCorrectApplicationCode()
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock

		var requestCompletionCounter = 0
		var depersonalizeTurn = -1

		let remoteApiMock = RemoteAPIProviderStub()
		remoteApiMock.getUserClosure = { _, _ in
			Thread.sleep(forTimeInterval: 0.2)
			return FetchUserDataResult.Failure(nil)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiMock

		// Launch fetch tasks
		let fetchTask1 = Task { @MainActor in
			_ = try await MobileMessaging.fetchUser()
			requestCompletionCounter += 1
		}
		let fetchTask2 = Task { @MainActor in
			_ = try await MobileMessaging.fetchUser()
			requestCompletionCounter += 1
		}
		let fetchTask3 = Task { @MainActor in
			_ = try await MobileMessaging.fetchUser()
			requestCompletionCounter += 1
		}

		// Launch depersonalize
		let depersonalizeTask = Task { @MainActor in
			_ = try await MobileMessaging.depersonalize()
			requestCompletionCounter += 1
			depersonalizeTurn = requestCompletionCounter
		}

		// Wait for all tasks
		_ = try await fetchTask1.value
		_ = try await fetchTask2.value
		_ = try await fetchTask3.value
		_ = try await depersonalizeTask.value

		XCTAssertGreaterThan(depersonalizeTurn, -1) // should have valid value
		XCTAssertLessThan(depersonalizeTurn, 4) // should not be the latest performed because has higher priority
	}
}
