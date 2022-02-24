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
	
	func testThatGeoCleanedUpAfterDepersonalize() {
        MMTestCase.startWithCorrectApplicationCode()
        MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		weak var depersonalizeFinished = expectation(description: "DepersonalizeFinished")
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
        MMTestCase.startWithCorrectApplicationCode()
        MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		weak var depersonalizeFinished = expectation(description: "Depersonalize")
		let user = MobileMessaging.getUser()!
		user.firstName = "Darth"
		user.customAttributes = ["bootsize": 9.5 as NSNumber]
		user.archiveDirty()

        XCTAssertEqual(mobileMessagingInstance.internalData().currentDepersonalizationStatus, MMSuccessPending.undefined)
		XCTAssertEqual(MobileMessaging.getUser()!.firstName, "Darth")
		XCTAssertEqual(MobileMessaging.getUser()!.customAttributes!["bootsize"] as? NSNumber, 9.5)
		
		MobileMessaging.depersonalize() { status, _ in
            XCTAssertEqual(status, MMSuccessPending.undefined)
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
        MMTestCase.startWithCorrectApplicationCode()
        MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
        mobileMessagingInstance.pushRegistrationId = "rand"
        
		weak var depersonalizeFinished = expectation(description: "Depersonalize")
		weak var messagesReceived = expectation(description: "messagesReceived")
		let sentMessagesCount: Int = 5
		var iterationCounter: Int = 0
		
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
        MMTestCase.startWithCorrectApplicationCode()
        MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
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
        MMTestCase.startWithCorrectApplicationCode()
        MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
		weak var depersonalizeFailed = expectation(description: "Depersonalize failed")
		weak var depersonalizeSucceeded = expectation(description: "Depersonalize succeded")

		prepareUserData()
        
		performFailedDepersonalizeCase() {
			depersonalizeFailed?.fulfill()
            self.mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
			self.performSuccessfullDepersonalizeCase() {
				depersonalizeSucceeded?.fulfill()
			}
		}

		waitForExpectations(timeout: 5) { _ in
			XCTAssertEqual(.success, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
			XCTAssertTrue(self.mobileMessagingInstance.messageHandler.isRunning)
			XCTAssertNil(MobileMessaging.getUser()!.firstName)
			XCTAssertNil(MobileMessaging.getUser()!.customAttributes?["bootsize"])
		}
	}

	func testThatAfterFailedDepersonalizeLimitExceeded_DepersonalizeStatusBecomesUndefined() {
        MMTestCase.startWithCorrectApplicationCode()
        MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
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

		waitForExpectations(timeout: 5) { _ in
			XCTAssertEqual(.undefined, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
			XCTAssertTrue(self.mobileMessagingInstance.messageHandler.isRunning)
			XCTAssertNil(MobileMessaging.getUser()!.firstName)
			XCTAssertNil(MobileMessaging.getUser()!.customAttributes?["bootsize"])
		}
	}

    func testThatPendingDepersonalizeKeptBetweenRestarts() {
        MMTestCase.startWithCorrectApplicationCode()
        MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
        weak var depersonalizeFailed = expectation(description: "Depersonalize failed")
        prepareUserData()
        
        performFailedDepersonalizeCase() {
            XCTAssertEqual(.pending, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus)
            MobileMessaging.sharedInstance?.doStop()
            
            MMTestCase.startWithCorrectApplicationCode()
            depersonalizeFailed?.fulfill()
        }
        
        waitForExpectations(timeout: 20) { _ in
            XCTAssertEqual(MMSuccessPending.pending.rawValue, self.mobileMessagingInstance.internalData().currentDepersonalizationStatus.rawValue)
            XCTAssertFalse(self.mobileMessagingInstance.messageHandler.isRunning)
            XCTAssertNil(MobileMessaging.getUser()!.firstName)
            XCTAssertNil(MobileMessaging.getUser()!.customAttributes?["bootsize"])
        }
    }

	func testThatAPNSUnregistersOnFailedDepersonalize() {
        MMTestCase.startWithCorrectApplicationCode()
        MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
		weak var depersonalizeFailed = expectation(description: "Depersonalize failed")
        weak var unregisterCalled = expectation(description: "unregisterCalled")
		let mock = ApnsRegistrationManagerMock(mmContext: mobileMessagingInstance)
		
		mock.unregisterCalled = {
            unregisterCalled?.fulfill()
		}
		mobileMessagingInstance.apnsRegistrationManager = mock

		prepareUserData()
		performFailedDepersonalizeCase() {
			depersonalizeFailed?.fulfill()
		}
		//TODO: don' register apns until .undefined

        waitForExpectations(timeout: 5, handler: nil)
	}

	func testThatAPNSRegistersOnReDepersonalize() {
        MMTestCase.startWithCorrectApplicationCode()
        MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
		weak var depersonalizeFailed = expectation(description: "Depersonalize failed")
		weak var depersonalizeSucceeded = expectation(description: "Depersonalize succeded")
        weak var unregisterCalled = expectation(description: "unregisterCalled")
        weak var registerCalled = expectation(description: "registerCalled")
		let mock = ApnsRegistrationManagerMock(mmContext: mobileMessagingInstance)
		mock.unregisterCalled = {
            unregisterCalled?.fulfill()
		}
		mock.registerCalled = {
            registerCalled?.fulfill()
		}

		prepareUserData()
		mobileMessagingInstance.apnsRegistrationManager = mock
		performFailedDepersonalizeCase() {
			depersonalizeFailed?.fulfill()
			self.performSuccessfullDepersonalizeCase() {
				depersonalizeSucceeded?.fulfill()
			}
		}
		
		waitForExpectations(timeout: 5, handler: nil)
	}

	func testDepersonalizeHasHigherPriorityThanUserDataOperations() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        MobileMessaging.sharedInstance?.remoteApiProvider = successfulDepersonalizeApiMock
        
		var requestCompletionCounter = 0
		var depersonalizeTurn = -1
		weak var depersonalizeFinished = expectation(description: "Depersonalize Finished")
		weak var fetchFinished1 = expectation(description: "fetchFinished")
		weak var fetchFinished2 = expectation(description: "fetchFinished")
		weak var fetchFinished3 = expectation(description: "fetchFinished")
		
		let remoteApiMock = RemoteAPIProviderStub()
		remoteApiMock.getUserClosure = {  (applicationCode, pushRegistrationId) in
			Thread.sleep(forTimeInterval: 0.2)
			return FetchUserDataResult.Failure(nil)
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiMock
		mobileMessagingInstance.userService.fetchFromServer(userInitiated: true) { (user, e) in
			requestCompletionCounter += 1
            fetchFinished1?.fulfill()
		}
		mobileMessagingInstance.userService.fetchFromServer(userInitiated: true) { (user, e) in
			requestCompletionCounter += 1
            fetchFinished2?.fulfill()
		}
		mobileMessagingInstance.userService.fetchFromServer(userInitiated: true) { (user, e) in
			requestCompletionCounter += 1
            fetchFinished3?.fulfill()
		}
		
		MobileMessaging.depersonalize() { status, _ in
			requestCompletionCounter += 1
            depersonalizeTurn = requestCompletionCounter
            depersonalizeFinished?.fulfill()
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
        
        XCTAssertNotNil(MobileMessaging.getInstallation()?.pushRegistrationId)
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
