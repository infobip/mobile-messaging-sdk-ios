//
//  DepersonalizeTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 04/04/2018.
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
	
	override func setUp() {
		super.setUp()
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
	}
	
	func testThatGeoCleanedUpAfterDepersonalize() {
		weak var depersonalizeFinished = expectation(description: "DepersonalizeFinished")
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
		
		mobileMessagingInstance.didReceiveRemoteNotification(payload) { _ in
			let validEntryRegions = MMGeofencingService.sharedInstance?.datasource.validRegionsForEntryEventNow(with: pulaId)
			XCTAssertEqual(validEntryRegions?.count, 1)
			XCTAssertEqual(validEntryRegions?.first?.dataSourceIdentifier, message.regions.first?.dataSourceIdentifier)
		
			MobileMessaging.depersonalize() { status, _ in
				XCTAssertTrue(status == MMSuccessPending.undefined)
				depersonalizeFinished?.fulfill()
			}
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
	
	func testThatUserDataCleanedUpAfterDepersonalize() {
		weak var depersonalizeFinished = expectation(description: "Depersonalize")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		let user = MobileMessaging.getUser()!
		user.firstName = "Darth"
		user.customAttributes = ["bootsize": 9.5 as NSNumber]
		user.archiveDirty()

		XCTAssertEqual(MobileMessaging.getUser()!.firstName, "Darth")
		XCTAssertEqual(MobileMessaging.getUser()!.customAttributes!["bootsize"] as? NSNumber, 9.5)
		
		MobileMessaging.depersonalize() { status, _ in
			XCTAssertTrue(status == MMSuccessPending.undefined)
			depersonalizeFinished?.fulfill()
		}
		
		waitForExpectations(timeout: 20) { _ in
			// assert there is no user data
			let user = MobileMessaging.getUser()!
			XCTAssertNil(user.firstName)
			XCTAssertNil(user.customAttributes?["bootsize"])
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
						MobileMessaging.depersonalize() { _, _ in
							depersonalizeFinished?.fulfill()
						}
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
		weak var depersonalizeFailed = expectation(description: "Depersonalize failed")
		prepareUserData()
		performFailedDepersonalizeCase() {
			depersonalizeFailed?.fulfill()
		}

		waitForExpectations(timeout: 20) { _ in
			XCTAssertEqual(.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
			XCTAssertFalse(self.mobileMessagingInstance.messageHandler.isRunning)
			XCTAssertNil(MobileMessaging.getUser()!.firstName)
			XCTAssertNil(MobileMessaging.getUser()!.customAttributes?["bootsize"])
		}
	}

	func testThatAfterSuccessfulReDepersonalize_DepersonalizeStatusIsSuccess() {
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
			XCTAssertEqual(.success, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
			XCTAssertTrue(self.mobileMessagingInstance.messageHandler.isRunning)
			XCTAssertNil(MobileMessaging.getUser()!.firstName)
			XCTAssertNil(MobileMessaging.getUser()!.customAttributes?["bootsize"])
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
			XCTAssertEqual(.undefined, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
			XCTAssertTrue(self.mobileMessagingInstance.messageHandler.isRunning)
			XCTAssertNil(MobileMessaging.getUser()!.firstName)
			XCTAssertNil(MobileMessaging.getUser()!.customAttributes?["bootsize"])
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
			XCTAssertNil(MobileMessaging.getUser()!.firstName)
			XCTAssertNil(MobileMessaging.getUser()!.customAttributes?["bootsize"])
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
		let remoteApiMock = RemoteAPIProviderStub()
		remoteApiMock.getUserClosure = {  (applicationCode, pushRegistrationId) in
			Thread.sleep(forTimeInterval: 0.2)
			return FetchUserDataResult.Failure(nil)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiMock
		mobileMessagingInstance.userService.fetchFromServer { (user, e) in
			DispatchQueue.main.async { requestCompletionCounter += 1;
				fetchFinished1?.fulfill() }
		}
		mobileMessagingInstance.userService.fetchFromServer { (user, e) in
			DispatchQueue.main.async { requestCompletionCounter += 1;
				fetchFinished2?.fulfill() }
		}
		mobileMessagingInstance.userService.fetchFromServer { (user, e) in
			DispatchQueue.main.async { requestCompletionCounter += 1;
				fetchFinished3?.fulfill() }
		}
		
		MobileMessaging.depersonalize() { status, _ in
			DispatchQueue.main.async { requestCompletionCounter += 1; depersonalizeTurn = requestCompletionCounter;
				depersonalizeFinished?.fulfill() }
		}

		waitForExpectations(timeout: 200) { _ in
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
		user.archiveDirty()

		XCTAssertEqual(MobileMessaging.getUser()!.firstName, "Darth")
		XCTAssertEqual(MobileMessaging.getUser()!.customAttributes!["bootsize"] as? NSNumber, 9.5)
	}

	private func performFailedDepersonalizeCase(then: (() -> Void)? = nil) {
		MobileMessaging.sharedInstance?.remoteApiProvider = failedDepersonalizeApiMock
		MobileMessaging.depersonalize() { s, e in
			XCTAssertEqual(MMSuccessPending.pending, s)
			XCTAssertNotNil(e)
			then?()
		}
	}

	private func performFailedDepersonalizeCaseWithOverlimit(then: (() -> Void)? = nil) {
		MobileMessaging.sharedInstance?.remoteApiProvider = failedDepersonalizeApiMock
		MobileMessaging.depersonalize() { s, e in
			XCTAssertEqual(MMSuccessPending.undefined, s)
			XCTAssertNotNil(e)
			then?()
		}
	}

	private func performSuccessfullDepersonalizeCase(then: (() -> Void)? = nil) {
		MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
		MobileMessaging.depersonalize() { s, e in
			XCTAssertEqual(MMSuccessPending.success, s)
			XCTAssertNil(e)
			then?()
		}
	}
}
