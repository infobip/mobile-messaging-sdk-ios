//
//  Example/Tests/MobileMessagingTests/UserIdentityMergeTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
import Foundation
@testable import MobileMessaging

class UserIdentityMergeTests: MMTestCase {

    override func setUp() {
        super.setUp()
        MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
    }

	func testInitializerWithDefaultParametersExternalUserId() {
		let identity = MMUserIdentity(externalUserId: "user123")
		XCTAssertNotNil(identity, "Identity should be created")
		XCTAssertEqual(identity?.externalUserId, "user123")
		XCTAssertNil(identity?.phones)
		XCTAssertNil(identity?.emails)
	}

	func testInitializerWithDefaultParametersPhones() {
		let identity = MMUserIdentity(phones: ["+1234567890"])
		XCTAssertNotNil(identity, "Identity should be created")
		XCTAssertEqual(identity?.phones, ["+1234567890"])
		XCTAssertNil(identity?.externalUserId)
		XCTAssertNil(identity?.emails)
	}

	func testInitializerWithDefaultParametersEmails() {
		let identity = MMUserIdentity(emails: ["user@example.com"])
		XCTAssertNotNil(identity, "Identity should be created")
		XCTAssertEqual(identity?.emails, ["user@example.com"])
		XCTAssertNil(identity?.externalUserId)
		XCTAssertNil(identity?.phones)
	}

	func testConvenienceConstructorWithEmptyArrayCreatesIdentity() {
		// Empty arrays should fail validation in the designated initializer
		let identityWithEmptyPhones = MMUserIdentity(phones: [], emails: nil, externalUserId: nil)
		XCTAssertNil(identityWithEmptyPhones, "Identity with empty phones array should fail validation")

		let identityWithEmptyEmails = MMUserIdentity(phones: nil, emails: [], externalUserId: nil)
		XCTAssertNil(identityWithEmptyEmails, "Identity with empty emails array should fail validation")
	}

	// MARK: - Merge Behavior Tests (Critical Bug Fix Verification)

	func testApplyExternalUserIdDoesNotClearPhoneAndEmail() {
		// Setup: Create a user with all identity fields populated
		let user = MMUser(json: JSON.parse("{}"))!
		user.externalUserId = "originalUserId"
		user.phones = ["123456789"]
		user.emails = ["original@example.com"]

		// Action: Apply identity with only externalUserId
		guard let identity = MMUserIdentity(externalUserId: "newUserId") else {
			XCTFail("Identity should be created")
			return
		}
		UserDataMapper.apply(userIdentity: identity, to: user)

		// Assert: Only externalUserId changed, phones/emails preserved
		XCTAssertEqual(user.externalUserId, "newUserId", "externalUserId should be updated")
		XCTAssertEqual(user.phones, ["123456789"], "phones should be preserved")
		XCTAssertEqual(user.emails, ["original@example.com"], "emails should be preserved")
	}

	func testApplyPhoneDoesNotClearEmailAndExternalUserId() {
		// Setup: Create a user with all identity fields populated
		let user = MMUser(json: JSON.parse("{}"))!
		user.externalUserId = "userId"
		user.phones = ["oldPhone"]
		user.emails = ["email@example.com"]

		// Action: Apply identity with only phones
		guard let identity = MMUserIdentity(phones: ["newPhone"]) else {
			XCTFail("Identity should be created")
			return
		}
		UserDataMapper.apply(userIdentity: identity, to: user)

		// Assert: Only phones changed, others preserved
		XCTAssertEqual(user.phones, ["newPhone"], "phones should be updated")
		XCTAssertEqual(user.emails, ["email@example.com"], "emails should be preserved")
		XCTAssertEqual(user.externalUserId, "userId", "externalUserId should be preserved")
	}

	func testApplyEmailDoesNotClearPhoneAndExternalUserId() {
		// Setup: Create a user with all identity fields populated
		let user = MMUser(json: JSON.parse("{}"))!
		user.externalUserId = "userId"
		user.phones = ["phone"]
		user.emails = ["old@example.com"]

		// Action: Apply identity with only emails
		guard let identity = MMUserIdentity(emails: ["new@example.com"]) else {
			XCTFail("Identity should be created")
			return
		}
		UserDataMapper.apply(userIdentity: identity, to: user)

		// Assert: Only emails changed, others preserved
		XCTAssertEqual(user.emails, ["new@example.com"], "emails should be updated")
		XCTAssertEqual(user.phones, ["phone"], "phones should be preserved")
		XCTAssertEqual(user.externalUserId, "userId", "externalUserId should be preserved")
	}

	func testApplyMultipleFieldsUpdatesAll() {
		// Setup: Create a user with all identity fields populated
		let user = MMUser(json: JSON.parse("{}"))!
		user.externalUserId = "oldUserId"
		user.phones = ["oldPhone"]
		user.emails = ["old@example.com"]

		// Action: Apply identity with multiple fields
		let identity = MMUserIdentity(phones: ["newPhone"], emails: ["new@example.com"], externalUserId: "newUserId")
		UserDataMapper.apply(userIdentity: identity!, to: user)

		// Assert: All provided fields are updated
		XCTAssertEqual(user.externalUserId, "newUserId", "externalUserId should be updated")
		XCTAssertEqual(user.phones, ["newPhone"], "phones should be updated")
		XCTAssertEqual(user.emails, ["new@example.com"], "emails should be updated")
	}

	func testApplyToUserWithNoExistingDataWorks() {
		// Setup: Create a user with no identity fields
		let user = MMUser(json: JSON.parse("{}"))!
		XCTAssertNil(user.externalUserId)
		XCTAssertNil(user.phones)
		XCTAssertNil(user.emails)

		// Action: Apply identity with externalUserId only
		guard let identity = MMUserIdentity(externalUserId: "newUserId") else {
			XCTFail("Identity should be created")
			return
		}
		UserDataMapper.apply(userIdentity: identity, to: user)

		// Assert: Only externalUserId is set
		XCTAssertEqual(user.externalUserId, "newUserId", "externalUserId should be set")
		XCTAssertNil(user.phones, "phones should remain nil")
		XCTAssertNil(user.emails, "emails should remain nil")
	}

	// MARK: - Integration Tests with personalize() API

	func testPersonalizeWithExternalUserIdPreservesExistingIdentityFields() {
		MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "123"
		weak var expectation = self.expectation(description: "personalize completed")

		// Setup: Create a user with existing identity fields
		let initialUser = MMUser(json: JSON.parse("{}"))!
		initialUser.phones = ["123456789"]
		initialUser.emails = ["existing@example.com"]
		initialUser.externalUserId = "originalId"
		initialUser.firstName = "John"
		initialUser.archiveCurrent()
		initialUser.archiveDirty()

		// Mock successful personalize response
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.personalizeClosure = { _, _, _, _ -> PersonalizeResult in
			// Server returns user with all fields intact
			let jsonStr = """
			{
				"phones": [{"number": "123456789"}],
				"emails": [{"address": "existing@example.com"}],
				"externalUserId": "newExternalId",
				"firstName": "John"
			}
			"""
			return PersonalizeResult.Success(MMUser(json: JSON.parse(jsonStr))!)
		}
		self.mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		// Action: Personalize with only externalUserId
		guard let identity = MMUserIdentity(externalUserId: "newExternalId") else {
			XCTFail("Identity should be created")
			return
		}

		MobileMessaging.personalize(
			withUserIdentity: identity,
			userAttributes: nil
		) { error in
			XCTAssertNil(error, "Personalize should succeed")
			let updatedUser = MobileMessaging.getUser()!
			XCTAssertEqual(updatedUser.externalUserId, "newExternalId", "externalUserId should be updated")
			XCTAssertEqual(updatedUser.phones, ["123456789"], "phones should be preserved")
			XCTAssertEqual(updatedUser.emails, ["existing@example.com"], "emails should be preserved")
			XCTAssertEqual(updatedUser.firstName, "John", "firstName should be preserved")
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20)
	}

	func testPersonalizeWithPhonesPreservesExistingIdentityFields() {
		MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "123"

		weak var expectation = self.expectation(description: "personalize completed")

		// Setup: Create a user with existing identity fields
		let initialUser = MMUser(json: JSON.parse("{}"))!
		initialUser.phones = ["oldPhone"]
		initialUser.emails = ["existing@example.com"]
		initialUser.externalUserId = "userId"
		initialUser.archiveCurrent()
		initialUser.archiveDirty()

		// Mock successful personalize response
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.personalizeClosure = { _, _, _, _ -> PersonalizeResult in
			let jsonStr = """
			{
				"phones": [{"number": "newPhone"}],
				"emails": [{"address": "existing@example.com"}],
				"externalUserId": "userId"
			}
			"""
			return PersonalizeResult.Success(MMUser(json: JSON.parse(jsonStr))!)
		}
		self.mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		// Action: Personalize with only phones
		guard let identity = MMUserIdentity(phones: ["newPhone"]) else {
			XCTFail("Identity should be created")
			return
		}

		MobileMessaging.personalize(
			withUserIdentity: identity,
			userAttributes: nil
		) { error in
			XCTAssertNil(error, "Personalize should succeed")
			let updatedUser = MobileMessaging.getUser()!
			XCTAssertEqual(updatedUser.phones, ["newPhone"], "phones should be updated")
			XCTAssertEqual(updatedUser.emails, ["existing@example.com"], "emails should be preserved")
			XCTAssertEqual(updatedUser.externalUserId, "userId", "externalUserId should be preserved")
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20)
	}

	func testPersonalizeWithEmailsPreservesExistingIdentityFields() {
		MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "123"

		weak var expectation = self.expectation(description: "personalize completed")

		// Setup: Create a user with existing identity fields
		let initialUser = MMUser(json: JSON.parse("{}"))!
		initialUser.phones = ["phone"]
		initialUser.emails = ["old@example.com"]
		initialUser.externalUserId = "userId"
		initialUser.archiveCurrent()
		initialUser.archiveDirty()

		// Mock successful personalize response
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.personalizeClosure = { _, _, _, _ -> PersonalizeResult in
			let jsonStr = """
			{
				"phones": [{"number": "phone"}],
				"emails": [{"address": "new@example.com"}],
				"externalUserId": "userId"
			}
			"""
			return PersonalizeResult.Success(MMUser(json: JSON.parse(jsonStr))!)
		}
		self.mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		// Action: Personalize with only emails
		guard let identity = MMUserIdentity(emails: ["new@example.com"]) else {
			XCTFail("Identity should be created")
			return
		}

		MobileMessaging.personalize(
			withUserIdentity: identity,
			userAttributes: nil
		) { error in
			XCTAssertNil(error, "Personalize should succeed")
			let updatedUser = MobileMessaging.getUser()!
			XCTAssertEqual(updatedUser.emails, ["new@example.com"], "emails should be updated")
			XCTAssertEqual(updatedUser.phones, ["phone"], "phones should be preserved")
			XCTAssertEqual(updatedUser.externalUserId, "userId", "externalUserId should be preserved")
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20)
	}

	// MARK: - Backward Compatibility Tests

	func testOriginalThreeParameterConstructorStillWorks() {
		let identity = MMUserIdentity(
			phones: ["123"],
			emails: ["email@test.com"],
			externalUserId: "userId"
		)
		XCTAssertNotNil(identity, "Original constructor should still work")
		XCTAssertEqual(identity!.phones, ["123"])
		XCTAssertEqual(identity!.emails, ["email@test.com"])
		XCTAssertEqual(identity!.externalUserId, "userId")
	}

	func testOriginalConstructorWithAllNilsFails() {
		let identity = MMUserIdentity(phones: nil, emails: nil, externalUserId: nil)
		XCTAssertNil(identity, "Constructor with all nil values should fail validation")
	}

	func testDefaultParametersAllowPartialCalls() {
		// Test that designated initializer with default parameters works correctly
		// Returns optional MMUserIdentity
		let identity1 = MMUserIdentity(externalUserId: "user123")
		XCTAssertNotNil(identity1, "Identity should be created")
		XCTAssertEqual(identity1?.externalUserId, "user123")

		let identity2 = MMUserIdentity(phones: ["123"])
		XCTAssertNotNil(identity2, "Identity should be created")
		XCTAssertEqual(identity2?.phones, ["123"])

		let identity3 = MMUserIdentity(emails: ["test@example.com"])
		XCTAssertNotNil(identity3, "Identity should be created")
		XCTAssertEqual(identity3?.emails, ["test@example.com"])
	}

	func testExistingPersonalizeCallsStillWork() {
		// Verify that existing personalize calls with the old syntax still work
		MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = "123"

		weak var expectation = self.expectation(description: "personalize completed")

		// Mock successful personalize response
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.personalizeClosure = { _, _, _, _ -> PersonalizeResult in
			let jsonStr = """
			{
				"phones": [{"number": "123"}],
				"emails": [{"address": "test@example.com"}],
				"externalUserId": "userId"
			}
			"""
			return PersonalizeResult.Success(MMUser(json: JSON.parse(jsonStr))!)
		}
		self.mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		// Old syntax with explicit nil parameters
		MobileMessaging.personalize(
			withUserIdentity: MMUserIdentity(phones: ["123"], emails: ["test@example.com"], externalUserId: "userId")!,
			userAttributes: nil
		) { error in
			XCTAssertNil(error, "Existing personalize syntax should still work")
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20)
	}
}

// MARK: - Mocks

let successfulPersonalizeApiMock = { () -> RemoteAPIProviderStub in
	let ret = RemoteAPIProviderStub()
	ret.personalizeClosure = { _, _, _, _ -> PersonalizeResult in
		// Return a successful personalize result with empty user
		return PersonalizeResult.Success(MMUser(json: JSON.parse("{}"))!)
	}
	return ret
}()
