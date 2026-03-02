// 
//  Example/Tests/MobileMessagingTests/PersonalizeTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
import Foundation
@testable import MobileMessaging

class PersonalizeTests: MMTestCase {

	override func setUp() {
		super.setUp()
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
	}


	//MARK: - Helper Methods
	private func prepareUserData() {
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let user = MobileMessaging.getUser()!
		user.firstName = "Darth"
		user.customAttributes = ["bootsize": 9.5 as NSNumber]
		MobileMessaging.persistUser(user)

		do {
			let user = MobileMessaging.getUser()!
			XCTAssertEqual(user.firstName, "Darth")
			XCTAssertEqual(user.customAttributes?["bootsize"] as? NSNumber, 9.5)
		}
	}

	private func performFailedDepersonalizeCase() async throws {
		MobileMessaging.sharedInstance?.remoteApiProvider = failedDepersonalizeApiMock
		do {
			try await MobileMessaging.personalize(forceDepersonalize: true, keepAsLead: false, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil)
			XCTFail("Should have thrown error")
		} catch {
			let s = self.mobileMessagingInstance.internalData().currentDepersonalizationStatus
			XCTAssertEqual(MMSuccessPending.pending, s)
		}
	}

	private func performAmbiguousPersonalizeCandidatesCase(userIdentity: MMUserIdentity) async throws {
		MobileMessaging.sharedInstance?.remoteApiProvider = ambiguousPersonalizeCandidatesApiMock
		do {
			try await MobileMessaging.personalize(forceDepersonalize: true, keepAsLead: false, userIdentity: userIdentity, userAttributes: nil)
			XCTFail("Should have thrown error")
		} catch {
			// Expected error
		}
	}

	private func performFailedDepersonalizeCaseWithOverlimit() async throws {
		MobileMessaging.sharedInstance?.remoteApiProvider = failedDepersonalizeApiMock
		do {
			try await MobileMessaging.personalize(forceDepersonalize: true, keepAsLead: false, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil)
			XCTFail("Should have thrown error")
		} catch {
			let s = self.mobileMessagingInstance.internalData().currentDepersonalizationStatus
			XCTAssertEqual(MMSuccessPending.undefined, s)
		}
	}

	private func performSuccessfullDepersonalizeCase() async throws {
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
		try await MobileMessaging.personalize(forceDepersonalize: true, keepAsLead: false, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil)
		let s = self.mobileMessagingInstance.internalData().currentDepersonalizationStatus
		XCTAssertEqual(MMSuccessPending.success, s)
	}


	func testThatDefaultMessageStorageCleanedUpAfterDepersonalize() async throws {
		MMTestCase.startWithCorrectApplicationCode()

		let sentMessagesCount: Int = 5

		mobileMessagingInstance.pushRegistrationId = "rand"
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

		try await MobileMessaging.personalize(forceDepersonalize: true, keepAsLead: false, userIdentity: MMUserIdentity(externalUserId: "externalUserId")!, userAttributes: nil)

		XCTAssertEqual(MMSuccessPending.undefined, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
		// assert there is not any message in message storage
		let messagesAfter = Message.MM_findAllWithPredicate(nil, context: MobileMessaging.defaultMessageStorage!.context!)
		XCTAssertTrue(messagesAfter == nil || messagesAfter?.isEmpty ?? true)
		// internal message storage must be cleaned up
		XCTAssertEqual(sentMessagesCount, MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")
	}

	func testThatAfterFailedDepersonalize_DepersonalizeStatusIsPending() async throws {
		MMTestCase.startWithCorrectApplicationCode()

		prepareUserData()
		try await performFailedDepersonalizeCase()

		let user = MobileMessaging.getUser()!
		XCTAssertEqual(.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
		XCTAssertFalse(self.mobileMessagingInstance.messageHandler.isRunning)
		XCTAssertNil(user.firstName)
		XCTAssertNil(user.customAttributes?["bootsize"])
	}

	func testThatAfterSuccessfulReDepersonalize_DepersonalizeStatusIsSuccessful() async throws {
		MMTestCase.startWithCorrectApplicationCode()

		prepareUserData()
		try await performFailedDepersonalizeCase()
		try await performSuccessfullDepersonalizeCase()

		let user = MobileMessaging.getUser()!
		XCTAssertEqual(self.mobileMessagingInstance.internalData().currentDepersonalizationStatus, .success)
		XCTAssertTrue(self.mobileMessagingInstance.messageHandler.isRunning)
		XCTAssertNil(user.firstName)
		XCTAssertNil(user.customAttributes?["bootsize"])
	}

	func testThatAfterFailedDepersonalizeLimitExceeded_DepersonalizeStatusBecomesUndefined() async throws {
		MMTestCase.startWithCorrectApplicationCode()

		DepersonalizationConsts.failuresNumberLimit = 2 // limit of failed attempts
		prepareUserData()
		try await performFailedDepersonalizeCase() // 1st attempt
		try await performFailedDepersonalizeCaseWithOverlimit() // 2nd attempt

		let user = MobileMessaging.getUser()!
		XCTAssertEqual(self.mobileMessagingInstance.internalData().currentDepersonalizationStatus, .undefined)
		XCTAssertTrue(self.mobileMessagingInstance.messageHandler.isRunning)
		XCTAssertNil(user.firstName)
		XCTAssertNil(user.customAttributes?["bootsize"])
	}

	func testThatPendingDepersonalizeKeptBetweenRestarts() async throws {
		MMTestCase.startWithCorrectApplicationCode()

		prepareUserData()
		try await performFailedDepersonalizeCase()
		XCTAssertEqual(.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
		MobileMessaging.sharedInstance?.doStop(nil)
		MMTestCase.startWithCorrectApplicationCode()

		XCTAssertEqual(.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
		XCTAssertFalse(self.mobileMessagingInstance.messageHandler.isRunning)
		let user = MobileMessaging.getUser()!
		XCTAssertNil(user.firstName)
		XCTAssertNil(user.customAttributes?["bootsize"])
	}

	func testThatAPNSUnregistersOnFailedDepersonalize() async throws {
		MMTestCase.startWithCorrectApplicationCode()

		let mock = ApnsRegistrationManagerMock(mmContext: mobileMessagingInstance)
		var unregisterCalled: Bool = false
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

		let mock = ApnsRegistrationManagerMock(mmContext: mobileMessagingInstance)
		var unregisterCalled: Bool = false
		var registerCalled: Bool = false
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

		var requestCompletionCounter = 0
		var depersonalizeTurn = -1
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		let remoteApiMock = RemoteAPIProviderStub()
		remoteApiMock.getUserClosure = {  _, _  in
			Thread.sleep(forTimeInterval: 0.2)
			return FetchUserDataResult.Failure(nil)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiMock

		// Launch user fetches (using withCheckedContinuation for internal API)
		let fetchTask1 = Task { @MainActor in
			await withCheckedContinuation { continuation in
				self.mobileMessagingInstance.userService.fetchFromServer(userInitiated: true) { (_, _) in
					requestCompletionCounter += 1
					continuation.resume()
				}
			}
		}
		let fetchTask2 = Task { @MainActor in
			await withCheckedContinuation { continuation in
				self.mobileMessagingInstance.userService.fetchFromServer(userInitiated: true) { (_, _) in
					requestCompletionCounter += 1
					continuation.resume()
				}
			}
		}
		let fetchTask3 = Task { @MainActor in
			await withCheckedContinuation { continuation in
				self.mobileMessagingInstance.userService.fetchFromServer(userInitiated: true) { (_, _) in
					requestCompletionCounter += 1
					continuation.resume()
				}
			}
		}

		// Launch personalize
		let personalizeTask = Task { @MainActor in
			try await MobileMessaging.personalize(forceDepersonalize: true, keepAsLead: false, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil)
			requestCompletionCounter += 1
			depersonalizeTurn = requestCompletionCounter
		}

		// Wait for all tasks
		_ = await fetchTask1.value
		_ = await fetchTask2.value
		_ = await fetchTask3.value
		_ = try await personalizeTask.value

		XCTAssertGreaterThan(depersonalizeTurn, -1) // should have valid value
		XCTAssertLessThan(depersonalizeTurn, 4) // should not be the latest performed because has higher priority
	}

	func testThatAfterAmbiguousPersonalizeCandidates_UserIdentityRollsBack() async throws {
		MMTestCase.startWithCorrectApplicationCode()

		mobileMessagingInstance.pushRegistrationId = "123"
		try await performAmbiguousPersonalizeCandidatesCase(userIdentity: MMUserIdentity(phones: ["1"], emails: ["2"], externalUserId: "123")!)

		let user = MobileMessaging.getUser()!
		XCTAssertNil(user.phones)
		XCTAssertNil(user.emails)
		XCTAssertNil(user.externalUserId)
	}

	func testThatAfterSuccessfulPersonalizeUserIdentityAndAttributesPersisted() async throws {
		MMTestCase.startWithCorrectApplicationCode()

		mobileMessagingInstance.pushRegistrationId = "123"

		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.personalizeClosure = { _, _, _, _ -> PersonalizeResult in
			let jsonStr = """
	{
		"phones": [
			{
				"number": "1"
			}
		],
		"emails": [
			{
				"address": "2",
			}
		],
		"customAttributes": {
			"bootsize": 9.5
		},
		"externalUserId": "externalUserId",
		"firstName": "firstName",
		"middleName": "middleName",
		"lastName": "lastName",
		"tags": ["t1", "t2"],
		"gender": "Male",
		"birthday": "1980-12-12"
	}
"""
			return PersonalizeResult.Success(MMUser.init(json: JSON.parse(jsonStr))!)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		try await MobileMessaging.personalize(forceDepersonalize: true, keepAsLead: false, userIdentity: MMUserIdentity(phones: ["1"], emails: ["2"], externalUserId: "externalUserId")!, userAttributes: nil)

		let user = MobileMessaging.getUser()!
		XCTAssertEqual(user.phones, ["1"])
		XCTAssertEqual(user.emails, ["2"])
		XCTAssertEqual(user.externalUserId, "externalUserId")
		XCTAssertEqual(user.firstName, "firstName")
		XCTAssertEqual(user.middleName, "middleName")
		XCTAssertEqual(user.lastName, "lastName")
		XCTAssertEqual(user.tags, ["t1", "t2"])
		XCTAssertEqual(user.gender, .Male)
		XCTAssertEqual(user.birthday, darthVaderDateOfBirth)
		XCTAssertEqual(user.customAttributes! as NSDictionary, ["bootsize": 9.5 as NSNumber])
	}
}

let ambiguousPersonalizeCandidatesApiMock = { () -> RemoteAPIProviderStub in
	let remoteApiProvider = RemoteAPIProviderStub()
	remoteApiProvider.personalizeClosure = { _, _, _, _ -> PersonalizeResult in

		let responseDict = ["requestError":
			["serviceException":
				[
					"text": "AMBIGUOUS_PERSONALIZE_CANDIDATES",
					"messageId": "AMBIGUOUS_PERSONALIZE_CANDIDATES"
				]
			]
		]
		let requestError = MMRequestError(json: JSON(responseDict))
		return PersonalizeResult.Failure(requestError?.foundationError)
	}
	return remoteApiProvider
}()
