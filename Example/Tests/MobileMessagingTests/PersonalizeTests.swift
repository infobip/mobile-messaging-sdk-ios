//
//  PersonalizeTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 17/01/2019.
//
//

import XCTest
import Foundation
@testable import MobileMessaging

class PersonalizeTests: MMTestCase {

	override func setUp() {
		super.setUp()
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
	}

	func testThatGeoCleanedUpAfterPersonalize() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var personalizeFinished = expectation(description: "personalizeFinished")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		let events = [makeEventDict(ofType: .entry, limit: 1)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}

		let geServiceStub = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance, locationManagerStub: LocationManagerStub())
		MMGeofencingService.sharedInstance = geServiceStub
		MMGeofencingService.sharedInstance!.start({ _ in })

		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload) { _ in
			let validEntryRegions = MMGeofencingService.sharedInstance?.datasource.validRegionsForEntryEventNow(with: pulaId)
			XCTAssertEqual(validEntryRegions?.count, 1)
			XCTAssertEqual(validEntryRegions?.first?.dataSourceIdentifier, message.regions.first?.dataSourceIdentifier)

			MobileMessaging.personalize(forceDepersonalize: true, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil, completion: { _ in
                XCTAssertEqual(MMSuccessPending.undefined.rawValue, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus.rawValue)
				personalizeFinished?.fulfill()
			})
		}

		waitForExpectations(timeout: 20) { _ in
			// assert there is no events
			if let events = GeoEventReportObject.MM_findAllInContext(self.storage.mainThreadManagedObjectContext!) {
				XCTAssertEqual(events.count, 0)
			}

			// assert there is no more monitored regions
			XCTAssertTrue(MMGeofencingService.sharedInstance?.locationManager.monitoredRegions.isEmpty ?? false)
		}
	}

	func testThatDefaultMessageStorageCleanedUpAfterDepersonalize() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var depersonalizeFinished = expectation(description: "Depersonalize")
		weak var messagesReceived = expectation(description: "messagesReceived")
		let sentMessagesCount: Int = 5
		var iterationCounter: Int = 0

		mobileMessagingInstance.pushRegistrationId = "rand"
		_ = mobileMessagingInstance.withDefaultMessageStorage()
		MobileMessaging.defaultMessageStorage?.start()

		XCTAssertEqual(0, MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")

		sendPushes(apnsNormalMessagePayload, count: sentMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: userInfo,  completion: { _ in
				iterationCounter += 1
				
                if iterationCounter == sentMessagesCount {
					MobileMessaging.defaultMessageStorage!.findAllMessages() { messages in
						
                        XCTAssertEqual(sentMessagesCount, messages!.count)
						XCTAssertEqual(sentMessagesCount, MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")
						messagesReceived?.fulfill()
						
                        MobileMessaging.personalize(forceDepersonalize: true, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil, completion: { _ in
							depersonalizeFinished?.fulfill()
						})
					}
				}
			})
		}

		waitForExpectations(timeout: 20) { _ in
			XCTAssertEqual(MMSuccessPending.undefined, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
			// assert there is not any message in message storage
			let messages = Message.MM_findAllWithPredicate(nil, context: MobileMessaging.defaultMessageStorage!.context!)
			XCTAssertTrue(messages == nil || messages?.isEmpty ?? true)
			// internal message storage must be cleaned up
			XCTAssertEqual(sentMessagesCount, MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")
		}
	}

	func testThatAfterFailedDepersonalize_DepersonalizeStatusIsPending() {
        MMTestCase.startWithCorrectApplicationCode()
        
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
        MMTestCase.startWithCorrectApplicationCode()
        
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
        MMTestCase.startWithCorrectApplicationCode()
        
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
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var depersonalizeFailed = expectation(description: "Depersonalize failed")
		prepareUserData()
		performFailedDepersonalizeCase() {
			XCTAssertEqual(.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
            MobileMessaging.sharedInstance?.doStop()
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
        MMTestCase.startWithCorrectApplicationCode()
        
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
        MMTestCase.startWithCorrectApplicationCode()
        
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
        MMTestCase.startWithCorrectApplicationCode()
        
		var requestCompletionCounter = 0
		var depersonalizeTurn = -1
		weak var depersonalizeFinished = expectation(description: "Depersonalize Finished")
		weak var fetchFinished1 = expectation(description: "fetchFinished")
		weak var fetchFinished2 = expectation(description: "fetchFinished")
		weak var fetchFinished3 = expectation(description: "fetchFinished")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		let remoteApiMock = RemoteAPIProviderStub()
		remoteApiMock.getUserClosure = {  _, _  in
			Thread.sleep(forTimeInterval: 0.2)
			return FetchUserDataResult.Failure(nil)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiMock
        mobileMessagingInstance.userService.fetchFromServer(userInitiated: true) { (_, _) in
			DispatchQueue.main.async { requestCompletionCounter += 1; fetchFinished1?.fulfill() }
		}
		mobileMessagingInstance.userService.fetchFromServer(userInitiated: true) { (_, _) in
			DispatchQueue.main.async { requestCompletionCounter += 1; fetchFinished2?.fulfill() }
		}
		mobileMessagingInstance.userService.fetchFromServer(userInitiated: true) { (_, _) in
			DispatchQueue.main.async { requestCompletionCounter += 1; fetchFinished3?.fulfill() }
		}
		MobileMessaging.personalize(forceDepersonalize: true, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil, completion: { _ in
			DispatchQueue.main.async {
				requestCompletionCounter += 1
				depersonalizeTurn = requestCompletionCounter
				depersonalizeFinished?.fulfill()
			}
		})

		waitForExpectations(timeout: 20) { _ in
			XCTAssertGreaterThan(depersonalizeTurn, -1) // should have valid value
			XCTAssertLessThan(depersonalizeTurn, 4) // should not be the latest performed because has higher priority
		}
	}

	func testThatAfterAmbiguousPersonalizeCandidates_UserIdentityRollsBack() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "expectation")
		mobileMessagingInstance.pushRegistrationId = "123"

		performAmbiguousPersonalizeCandidatesCase(userIdentity: MMUserIdentity(phones: ["1"], emails: ["2"], externalUserId: "123")!) {
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20, handler: { _ in
			let user = MobileMessaging.getUser()!
			XCTAssertNil(user.phones)
			XCTAssertNil(user.emails)
			XCTAssertNil(user.externalUserId)
		})
	}

	func testThatAfterSuccessfulPersonalizeUserIdentityAndAttributesPersisted() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "expectation")
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

		MobileMessaging.personalize(forceDepersonalize: true, userIdentity: MMUserIdentity(phones: ["1"], emails: ["2"], externalUserId: "externalUserId")!, userAttributes: nil, completion: { _ in
			expectation?.fulfill()
		})

		waitForExpectations(timeout: 20, handler: { _ in
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
		})
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
		MobileMessaging.sharedInstance?.remoteApiProvider = failedDepersonalizeApiMock
		MobileMessaging.personalize(forceDepersonalize: true, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil, completion: { e in
			let s = self.mobileMessagingInstance.internalData().currentDepersonalizationStatus
			XCTAssertEqual(MMSuccessPending.pending, s)
			XCTAssertNotNil(e)
			then?()
		})
	}

	private func performAmbiguousPersonalizeCandidatesCase(userIdentity: MMUserIdentity, then: (() -> Void)? = nil) {
		MobileMessaging.sharedInstance?.remoteApiProvider = ambiguousPersonalizeCandidatesApiMock
		MobileMessaging.personalize(forceDepersonalize: true, userIdentity: userIdentity, userAttributes: nil, completion: { e in
			XCTAssertNotNil(e)
			then?()
		})
	}

	private func performFailedDepersonalizeCaseWithOverlimit(then: (() -> Void)? = nil) {
		MobileMessaging.sharedInstance?.remoteApiProvider = failedDepersonalizeApiMock
		MobileMessaging.personalize(forceDepersonalize: true, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil, completion: { e in
			let s = self.mobileMessagingInstance.internalData().currentDepersonalizationStatus
			XCTAssertEqual(MMSuccessPending.undefined, s)
			XCTAssertNotNil(e)
			then?()
		})
	}

	private func performSuccessfullDepersonalizeCase(then: (() -> Void)? = nil) {
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
		MobileMessaging.personalize(forceDepersonalize: true, userIdentity: MMUserIdentity(phones: nil, emails: nil, externalUserId: "externalUserId")!, userAttributes: nil, completion: { e in
			let s = self.mobileMessagingInstance.internalData().currentDepersonalizationStatus
			XCTAssertEqual(MMSuccessPending.success, s)
			XCTAssertNil(e)
			then?()
		})
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
