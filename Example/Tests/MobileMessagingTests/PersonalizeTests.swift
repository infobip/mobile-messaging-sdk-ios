//
//  PersonalizeTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 17/01/2019.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import XCTest
import Foundation
@testable import MobileMessaging

class PersonalizeTests: MMTestCase {

	override func setUp() {
		super.setUp()
		MobileMessaging.sharedInstance?.remoteApiProvider.registrationQueue = successfulDepersonalizeApiMock
		MobileMessaging.sharedInstance?.remoteApiProvider.messageSyncQueue = successfulDepersonalizeApiMock
	}

	func testThatGeoCleanedUpAfterPersonalize() {
		weak var personalizeFinished = expectation(description: "personalizeFinished")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		let events = [makeEventDict(ofType: .entry, limit: 1)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}

		let geServiceStub = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance, locationManagerStub: LocationManagerStub())
		GeofencingService.sharedInstance = geServiceStub
		GeofencingService.sharedInstance!.start({ _ in })

		mobileMessagingInstance.didReceiveRemoteNotification(payload) { _ in
			let validEntryRegions = GeofencingService.sharedInstance?.datasource.validRegionsForEntryEventNow(with: pulaId)
			XCTAssertEqual(validEntryRegions?.count, 1)
			XCTAssertEqual(validEntryRegions?.first?.dataSourceIdentifier, message.regions.first?.dataSourceIdentifier)

			MobileMessaging.personalize(forceDepersonalize: true, userIdentity: UserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil, completion: { _ in
				XCTAssertTrue(self.mobileMessagingInstance.internalData().currentDepersonalizationStatus == SuccessPending.undefined)
				personalizeFinished?.fulfill()
			})
		}

		waitForExpectations(timeout: 20) { _ in
			// assert there is no events
			if let events = GeoEventReportObject.MM_findAllInContext(self.storage.mainThreadManagedObjectContext!) {
				XCTAssertEqual(events.count, 0)
			}

			// assert there is no more monitored regions
			XCTAssertTrue(GeofencingService.sharedInstance?.locationManager.monitoredRegions.isEmpty ?? false)
		}
	}

	func testThatUserAttributesAppliedAfterPersonalize() {
		weak var depersonalizeFinished = expectation(description: "Depersonalize")

		let responseStub: (Any) -> JSON? = { request -> JSON? in
			switch request {
			case (is PostPersonalize):
				let jsonStr = """
	{
		"firstName": "John",
		"externalUserId": "externalUserId",
		"lastName": "Dow",
		"middleName": "S",
		"tags": ["tag1","tag2"],
		"gender": "Male",
		"customAttributes": {
			"bootsize": 9
		}
	}
"""
				return JSON.parse(jsonStr)
			default:
				return nil
			}
		}

		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(
			performRequestCompanionBlock: nil,
			completionCompanionBlock: nil,
			responseSubstitution: responseStub)

		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let user = MobileMessaging.getUser()!
		user.firstName = "Darth"
		user.customAttributes = ["bootsize": 9.5 as NSNumber]
		MobileMessaging.persistUser(user)

		XCTAssertEqual(MobileMessaging.getUser()!.firstName, "Darth")
		XCTAssertEqual(MobileMessaging.getUser()!.customAttributes! as NSDictionary, ["bootsize": 9.5 as NSNumber])

		let givenUserAttributes = UserAttributes(firstName: "John", middleName: nil, lastName: "Dow", tags: ["tag1", "tag2"], gender: .Male, birthday: nil, customAttributes: ["bootsize": NSNumber(value: 9)])
		MobileMessaging.personalize(forceDepersonalize: true, userIdentity: UserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: givenUserAttributes, completion: { _ in
			XCTAssertTrue(self.mobileMessagingInstance.internalData().currentDepersonalizationStatus == SuccessPending.undefined)
			depersonalizeFinished?.fulfill()
		})

		waitForExpectations(timeout: 20) { _ in
			// assert there is no user data
			let user = MobileMessaging.getUser()!
			XCTAssertEqual(user.firstName, "John")
			XCTAssertEqual(user.middleName, "S")
			XCTAssertEqual(user.externalUserId, "externalUserId")
			XCTAssertEqual(user.lastName, "Dow")
			XCTAssertEqual(user.tags, ["tag1","tag2"])
			XCTAssertEqual(user.gender, .Male)
			XCTAssertEqual(user.customAttributes! as NSDictionary, ["bootsize": NSNumber(value: 9)])
		}
	}

	func testThatDefaultMessageStorageCleanedUpAfterDepersonalize() {
		weak var depersonalizeFinished = expectation(description: "Depersonalize")
		weak var messagesReceived = expectation(description: "messagesReceived")
		let sentMessagesCount: Int = 5
		var iterationCounter: Int = 0

		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		_ = mobileMessagingInstance.withDefaultMessageStorage()
		MobileMessaging.defaultMessageStorage?.start()

		XCTAssertEqual(0, MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")

		sendPushes(apnsNormalMessagePayload, count: sentMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo,  completion: { _ in
				iterationCounter += 1
				if iterationCounter == sentMessagesCount {
					MobileMessaging.defaultMessageStorage!.findAllMessages() { messages in
						XCTAssertEqual(sentMessagesCount, messages!.count)
						XCTAssertEqual(sentMessagesCount, MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")
						messagesReceived?.fulfill()
						MobileMessaging.personalize(forceDepersonalize: true, userIdentity: UserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil, completion: { _ in
							depersonalizeFinished?.fulfill()
						})
					}
				}
			})
		}

		waitForExpectations(timeout: 20) { _ in
			XCTAssertEqual(SuccessPending.undefined, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
			// assert there is not any message in message storage
			let messages = Message.MM_findAllWithPredicate(nil, context: MobileMessaging.defaultMessageStorage!.context!)
			XCTAssertTrue(messages == nil || messages?.isEmpty ?? true)
			// internal message storage must be cleaned up
			XCTAssertEqual(sentMessagesCount, MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")
		}
	}

	func testThatAfterFailedDepersonalize_DepersonalizeStatusIsPending() {
		weak var depersonalizeFailed = expectation(description: "Depersonalize failed")
		prepareUserData()
		performFailedDepersonalizeCase() {
			depersonalizeFailed?.fulfill()
		}

		waitForExpectations(timeout: 20) { _ in
			let user = MobileMessaging.getUser()!
			XCTAssertEqual(.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
			XCTAssertFalse(self.mobileMessagingInstance.messageHandler.isRunning)
			XCTAssertNil(user.firstName)
			XCTAssertNil(user.customAttributes?["bootsize"])
		}
	}

	func testThatAfterSuccessfulReDepersonalize_DepersonalizeStatusIsSuccessful() {
		weak var depersonalizeFailed = expectation(description: "Depersonalize failed")
		weak var depersonalizeSucceeded = expectation(description: "Depersonalize succeded")

		prepareUserData()
		performFailedDepersonalizeCase() {
			depersonalizeFailed?.fulfill()
			self.performSuccessfullDepersonalizeCase() {
				depersonalizeSucceeded?.fulfill()
			}
		}

		waitForExpectations(timeout: 20) { _ in
			let user = MobileMessaging.getUser()!
			XCTAssertEqual(self.mobileMessagingInstance.internalData().currentDepersonalizationStatus, .success)
			XCTAssertTrue(self.mobileMessagingInstance.messageHandler.isRunning)
			XCTAssertNil(user.firstName)
			XCTAssertNil(user.customAttributes?["bootsize"])
		}
	}

	func testThatAfterFailedDepersonalizeLimitExceeded_DepersonalizeStatusBecomesUndefined() {
		weak var depersonalizeFailed1 = expectation(description: "Depersonalize failed")
		weak var depersonalizeFailed2 = expectation(description: "Depersonalize failed")

		DepersonalizationConsts.failuresNumberLimit = 2 // limit of failed attempts
		prepareUserData()
		performFailedDepersonalizeCase() { // 1st attempt
			depersonalizeFailed1?.fulfill()
			self.performFailedDepersonalizeCaseWithOverlimit() { // 2nd attempt
				depersonalizeFailed2?.fulfill()
			}
		}

		waitForExpectations(timeout: 20) { _ in
			let user = MobileMessaging.getUser()!
			XCTAssertEqual(self.mobileMessagingInstance.internalData().currentDepersonalizationStatus, .undefined)
			XCTAssertTrue(self.mobileMessagingInstance.messageHandler.isRunning)
			XCTAssertNil(user.firstName)
			XCTAssertNil(user.customAttributes?["bootsize"])
		}
	}

	func testThatPendingDepersonalizeKeptBetweenRestarts() {
		weak var depersonalizeFailed = expectation(description: "Depersonalize failed")
		prepareUserData()
		performFailedDepersonalizeCase() {
			XCTAssertEqual(.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
			MobileMessaging.stop()
			MMTestCase.startWithCorrectApplicationCode()
			depersonalizeFailed?.fulfill()
		}

		waitForExpectations(timeout: 20) { _ in
			XCTAssertEqual(.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
			XCTAssertFalse(self.mobileMessagingInstance.messageHandler.isRunning)
			let user = MobileMessaging.getUser()!
			XCTAssertNil(user.firstName)
			XCTAssertNil(user.customAttributes?["bootsize"])
		}
	}

	func testThatAPNSUnregistersOnFailedDepersonalize() {
		weak var depersonalizeFailed = expectation(description: "Depersonalize failed")
		let mock = ApnsRegistrationManagerMock(mmContext: mobileMessagingInstance)
		var unregisterCalled: Bool = false
		mock.unregisterCalled = {
			unregisterCalled = true
		}
		mobileMessagingInstance.apnsRegistrationManager = mock

		prepareUserData()
		performFailedDepersonalizeCase() {
			depersonalizeFailed?.fulfill()
		}
		//TODO: don' register apns until .undefined

		waitForExpectations(timeout: 20) { _ in
			XCTAssertTrue(unregisterCalled)
		}
	}

	func testThatAPNSRegistersOnReDepersonalize() {
		weak var depersonalizeFailed = expectation(description: "Depersonalize failed")
		weak var depersonalizeSucceeded = expectation(description: "Depersonalize succeded")
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
		performFailedDepersonalizeCase() {
			depersonalizeFailed?.fulfill()
			self.performSuccessfullDepersonalizeCase() {
				depersonalizeSucceeded?.fulfill()
			}
		}

		waitForExpectations(timeout: 20) { _ in
			XCTAssertTrue(unregisterCalled)
			XCTAssertTrue(registerCalled)
		}
	}

	func testDepersonalizeHasHigherPriorityThanUserDataOperations() {
		var requestCompletionCounter = 0
		var depersonalizeTurn = -1
		weak var depersonalizeFinished = expectation(description: "Depersonalize Finished")
		weak var fetchFinished1 = expectation(description: "fetchFinished")
		weak var fetchFinished2 = expectation(description: "fetchFinished")
		weak var fetchFinished3 = expectation(description: "fetchFinished")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		mobileMessagingInstance.userService.fetchFromServer { (user, e) in
			requestCompletionCounter += 1
			fetchFinished1?.fulfill()
		}
		mobileMessagingInstance.userService.fetchFromServer { (user, e) in
			requestCompletionCounter += 1
			fetchFinished2?.fulfill()
		}
		mobileMessagingInstance.userService.fetchFromServer { (user, e) in
			requestCompletionCounter += 1
			fetchFinished3?.fulfill()
		}
		MobileMessaging.personalize(forceDepersonalize: true, userIdentity: UserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil, completion: { _ in
			requestCompletionCounter += 1
			depersonalizeTurn = requestCompletionCounter
			depersonalizeFinished?.fulfill()
		})

		waitForExpectations(timeout: 20) { _ in
			XCTAssertGreaterThan(depersonalizeTurn, -1) // should have valid value
			XCTAssertLessThan(depersonalizeTurn, 4) // should not be the latest performed because has higher priority
		}
	}

	//MARK: - private
	private func prepareUserData() {
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let user = MobileMessaging.getUser()!
		user.firstName = "Darth"
		user.customAttributes = ["bootsize": 9.5 as NSNumber]
		MobileMessaging.persistUser(user)

		do{
			let user = MobileMessaging.getUser()!
			XCTAssertEqual(user.firstName, "Darth")
			XCTAssertEqual(user.customAttributes?["bootsize"] as? NSNumber, 9.5)
		}
	}

	private func performFailedDepersonalizeCase(then: (() -> Void)? = nil) {
		MobileMessaging.sharedInstance?.remoteApiProvider.registrationQueue = failedDepersonalizeApiMock
		MobileMessaging.personalize(forceDepersonalize: true, userIdentity: UserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil, completion: { e in
			let s = self.mobileMessagingInstance.internalData().currentDepersonalizationStatus
			XCTAssertEqual(SuccessPending.pending, s)
			XCTAssertNotNil(e)
			then?()
		})
	}

	private func performFailedDepersonalizeCaseWithOverlimit(then: (() -> Void)? = nil) {
		MobileMessaging.sharedInstance?.remoteApiProvider.registrationQueue = failedDepersonalizeApiMock
		MobileMessaging.personalize(forceDepersonalize: true, userIdentity: UserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil, completion: { e in
			let s = self.mobileMessagingInstance.internalData().currentDepersonalizationStatus
			XCTAssertEqual(SuccessPending.undefined, s)
			XCTAssertNotNil(e)
			then?()
		})
	}

	private func performSuccessfullDepersonalizeCase(then: (() -> Void)? = nil) {
		MobileMessaging.sharedInstance?.remoteApiProvider.registrationQueue = successfulDepersonalizeApiMock
		MobileMessaging.personalize(forceDepersonalize: true, userIdentity: UserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil, completion: { e in
			let s = self.mobileMessagingInstance.internalData().currentDepersonalizationStatus
			XCTAssertEqual(SuccessPending.success, s)
			XCTAssertNil(e)
			then?()
		})
	}
}
