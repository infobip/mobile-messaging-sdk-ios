//
//  LogoutTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 04/04/2018.
//

import XCTest
import Foundation
@testable import MobileMessaging

let successfulLogoutApiMock = MMRemoteAPIMock(performRequestCompanionBlock: nil, completionCompanionBlock: nil, responseSubstitution: { request -> JSON? in
	switch request {
	case is LogoutRequest:
		return JSON.parse("")
	case is MessagesSyncRequest:
		return nil
	default:
		return nil
	}
})


let failedLogoutApiMock = MMRemoteAPIMock(performRequestCompanionBlock: nil, completionCompanionBlock: nil, responseSubstitution: { request -> JSON? in
	switch request {
	case is LogoutRequest:
		return nil
	case is MessagesSyncRequest:
		return nil
	default:
		return nil
	}
})

class LogoutTests: MMTestCase {
	
	override func setUp() {
		super.setUp()
		MobileMessaging.sharedInstance?.remoteApiProvider.registrationQueue = successfulLogoutApiMock
		MobileMessaging.sharedInstance?.remoteApiProvider.messageSyncQueue = successfulLogoutApiMock
	}
	
	func testThatGeoCleanedUpAfterLogout() {
		weak var logoutFinished = expectation(description: "logoutFinished")
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		let events = [makeEventDict(ofType: .entry, limit: 1)]
		let payload = makeApnsPayload(withEvents: events, deliveryTime: nil, regions: [modernPulaDict])
		guard let message = MMGeoMessage(payload: payload, deliveryMethod: .undefined, seenDate: nil, deliveryReportDate: nil, seenStatus: .NotSeen, isDeliveryReportSent: false) else {
			XCTFail()
			return
		}
		
		let geServiceStub = GeofencingServiceAlwaysRunningStub(mmContext: self.mobileMessagingInstance, locationManagerStub: LocationManagerStub())
		GeofencingService.sharedInstance = geServiceStub
		GeofencingService.sharedInstance!.start()
		
		mobileMessagingInstance.didReceiveRemoteNotification(payload) { _ in
			let validEntryRegions = GeofencingService.sharedInstance?.datasource.validRegionsForEntryEventNow(with: pulaId)
			XCTAssertEqual(validEntryRegions?.count, 1)
			XCTAssertEqual(validEntryRegions?.first?.dataSourceIdentifier, message.regions.first?.dataSourceIdentifier)
		
			MobileMessaging.sharedInstance?.currentInstallation.logout(callAndForget: true) { _ in
				logoutFinished?.fulfill()
			}
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
	
	func testThatUserDataCleanedUpAfterLogout() {
		weak var logoutFinished = expectation(description: "logoutFinished")
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		
		mobileMessagingInstance.currentUser.firstName = "Darth"
		mobileMessagingInstance.currentUser.set(customData: CustomUserDataValue(double: 9.5), forKey: "bootsize")
		mobileMessagingInstance.currentUser.persist()
		
		XCTAssertEqual("Darth", mobileMessagingInstance.currentUser.firstName)
		XCTAssertEqual(9.5, mobileMessagingInstance.currentUser.customData(forKey: "bootsize")?.double)
		
		MobileMessaging.sharedInstance?.currentInstallation.logout(callAndForget: true) { _ in
			logoutFinished?.fulfill()
		}
		
		waitForExpectations(timeout: 20) { _ in
			// assert there is no user data
			XCTAssertNil(self.mobileMessagingInstance.currentUser.firstName)
			XCTAssertNil(self.mobileMessagingInstance.currentUser.customData(forKey: "bootsize"))
		}
	}
	
	func testThatDefaultMessageStorageCleanedUpAfterLogout() {
		weak var logoutFinished = expectation(description: "logoutFinished")
		weak var messagesReceived = expectation(description: "messagesReceived")
		let sentMessagesCount: Int = 5
		var iterationCounter: Int = 0
		
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		_ = mobileMessagingInstance.withDefaultMessageStorage()
		MobileMessaging.defaultMessageStorage?.start()

		XCTAssertEqual(0, self.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")
		
		sendPushes(apnsNormalMessagePayload, count: sentMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo,  completion: { _ in
				iterationCounter += 1
				if iterationCounter == sentMessagesCount {
					MobileMessaging.defaultMessageStorage!.findAllMessages() { messages in
						XCTAssertEqual(sentMessagesCount, messages!.count)
						XCTAssertEqual(sentMessagesCount, self.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")
						messagesReceived?.fulfill()
						MobileMessaging.sharedInstance?.currentInstallation.logout(callAndForget: true) { _ in
							logoutFinished?.fulfill()
						}
					}
				}
			})
		}
		
		waitForExpectations(timeout: 20) { _ in
			XCTAssertEqual(LogoutStatus.undefined, self.mobileMessagingInstance.currentInstallation.currentLogoutStatus)
			// assert there is not any message in message storage
			let messages = Message.MM_findAllWithPredicate(nil, context: MobileMessaging.defaultMessageStorage!.context!)
			XCTAssertTrue(messages == nil || messages?.isEmpty ?? true)
			// internal message storage must be cleaned up
			XCTAssertEqual(sentMessagesCount, self.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")
		}
	}

	func testThatAfterFailedLogout_LogoutStatusIsPending() {
		weak var logoutFailed = expectation(description: "logout failed")
		prepateUserData()
		performFailedLogoutCase() {
			logoutFailed?.fulfill()
		}

		waitForExpectations(timeout: 20) { _ in
			XCTAssertEqual(.pending, self.mobileMessagingInstance.currentInstallation.currentLogoutStatus)
			XCTAssertFalse(self.mobileMessagingInstance.messageHandler.isRunning)
			XCTAssertNil(self.mobileMessagingInstance.currentUser.firstName)
			XCTAssertNil(self.mobileMessagingInstance.currentUser.customData(forKey: "bootsize"))
		}
	}

	func testThatAfterSuccessfulReLogout_LogoutStatusIsUndefined() {
		weak var logoutFailed = expectation(description: "logout failed")
		weak var logoutSucceeded = expectation(description: "logout succeded")

		prepateUserData()
		performFailedLogoutCase() {
			logoutFailed?.fulfill()
			self.performSuccessfullLogoutCase() {
				logoutSucceeded?.fulfill()
			}
		}

		waitForExpectations(timeout: 20) { _ in
			XCTAssertEqual(.undefined, self.mobileMessagingInstance.currentInstallation.currentLogoutStatus)
			XCTAssertTrue(self.mobileMessagingInstance.messageHandler.isRunning)
			XCTAssertNil(self.mobileMessagingInstance.currentUser.firstName)
			XCTAssertNil(self.mobileMessagingInstance.currentUser.customData(forKey: "bootsize"))
		}
	}

	func testThatAfterFailedLogoutLimitExceeded_LogoutStatusBecomesUndefined() {
		weak var logoutFailed1 = expectation(description: "logout failed")
		weak var logoutFailed2 = expectation(description: "logout failed")

		LogoutConsts.failuresNumberLimit = 2 // limit of failed attempts
		prepateUserData()
		performFailedLogoutCase() { // 1st attempt
			logoutFailed1?.fulfill()
			self.performFailedLogoutCase() { // 2nd attempt
				logoutFailed2?.fulfill()
			}
		}

		waitForExpectations(timeout: 20) { _ in
			XCTAssertEqual(.undefined, self.mobileMessagingInstance.currentInstallation.currentLogoutStatus)
			XCTAssertTrue(self.mobileMessagingInstance.messageHandler.isRunning)
			XCTAssertNil(self.mobileMessagingInstance.currentUser.firstName)
			XCTAssertNil(self.mobileMessagingInstance.currentUser.customData(forKey: "bootsize"))
		}
	}

	func testThatPendingLogoutKeptBetweenRestarts() {
		weak var logoutFailed = expectation(description: "logout failed")
		prepateUserData()
		performFailedLogoutCase() {
			XCTAssertEqual(.pending, self.mobileMessagingInstance.currentInstallation.currentLogoutStatus)
			MobileMessaging.stop()
			self.startWithCorrectApplicationCode()
			logoutFailed?.fulfill()
		}

		waitForExpectations(timeout: 20) { _ in
			XCTAssertEqual(.pending, self.mobileMessagingInstance.currentInstallation.currentLogoutStatus)
			XCTAssertFalse(self.mobileMessagingInstance.messageHandler.isRunning)
			XCTAssertNil(self.mobileMessagingInstance.currentUser.firstName)
			XCTAssertNil(self.mobileMessagingInstance.currentUser.customData(forKey: "bootsize"))
		}
	}

	func testThatAPNSUnregistersOnFailedLogout() {
		weak var logoutFailed = expectation(description: "logout failed")
		let mock = ApnsRegistrationManagerMock(mmContext: mobileMessagingInstance)
		var unregisterCalled: Bool = false
		mock.unregisterCalled = {
			unregisterCalled = true
		}
		mobileMessagingInstance.apnsRegistrationManager = mock

		prepateUserData()
		performFailedLogoutCase() {
			logoutFailed?.fulfill()
		}
		//TODO: don' register apns until .undefined

		waitForExpectations(timeout: 20) { _ in
			XCTAssertTrue(unregisterCalled)
		}
	}

	func testThatAPNSRegistersOnReLogout() {
		weak var logoutFailed = expectation(description: "logout failed")
		weak var logoutSucceeded = expectation(description: "logout succeded")
		let mock = ApnsRegistrationManagerMock(mmContext: mobileMessagingInstance)
		var unregisterCalled: Bool = false
		var registerCalled: Bool = false
		mock.unregisterCalled = {
			unregisterCalled = true
		}
		mock.registerCalled = {
			registerCalled = true
		}

		prepateUserData()
		mobileMessagingInstance.apnsRegistrationManager = mock
		performFailedLogoutCase() {
			logoutFailed?.fulfill()
			self.performSuccessfullLogoutCase() {
				logoutSucceeded?.fulfill()
			}
		}
		
		waitForExpectations(timeout: 20) { _ in
			XCTAssertTrue(unregisterCalled)
			XCTAssertTrue(registerCalled)
		}
	}

	//MARK: - private
	private func prepateUserData() {
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID

		mobileMessagingInstance.currentUser.firstName = "Darth"
		mobileMessagingInstance.currentUser.set(customData: CustomUserDataValue(double: 9.5), forKey: "bootsize")
		mobileMessagingInstance.currentUser.persist()

		XCTAssertEqual("Darth", mobileMessagingInstance.currentUser.firstName)
		XCTAssertEqual(9.5, mobileMessagingInstance.currentUser.customData(forKey: "bootsize")?.double)
	}

	private func performFailedLogoutCase(then: (() -> Void)? = nil) {
		MobileMessaging.sharedInstance?.remoteApiProvider.registrationQueue = failedLogoutApiMock
		MobileMessaging.sharedInstance?.currentInstallation.logout(callAndForget: true) { _ in
			then?()
		}
	}

	private func performSuccessfullLogoutCase(then: (() -> Void)? = nil) {
		MobileMessaging.sharedInstance?.remoteApiProvider.registrationQueue = successfulLogoutApiMock
		MobileMessaging.sharedInstance?.currentInstallation.logout(callAndForget: true) { _ in
			then?()
		}
	}
}
