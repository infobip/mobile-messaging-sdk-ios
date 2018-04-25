//
//  LogoutTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 04/04/2018.
//

import XCTest
import Foundation
@testable import MobileMessaging

class LogoutTests: MMTestCase {
	
	override func setUp() {
		super.setUp()
		let responseStub: (Any) -> JSON? = { request -> JSON? in
			switch request {
			case is LogoutRequest:
				return JSON.parse("")
			case is MessagesSyncRequest:
				return nil
			default:
				return nil
			}
		}
		let apiMock = MMRemoteAPIMock(appCode: MMTestConstants.kTestCorrectApplicationCode, mmContext: self.mobileMessagingInstance, performRequestCompanionBlock: nil, completionCompanionBlock: nil, responseSubstitution: responseStub)
		MobileMessaging.sharedInstance?.remoteApiProvider.registrationQueue = apiMock
		MobileMessaging.sharedInstance?.remoteApiProvider.messageSyncQueue = apiMock
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
		
			MobileMessaging.logout { _ in
				logoutFinished?.fulfill()
			}
		}
		
		waitForExpectations(timeout: 20000) { _ in
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
		
		MobileMessaging.logout { _ in logoutFinished?.fulfill() }
		
		waitForExpectations(timeout: 20) { _ in
			// assert there is no user data
			XCTAssertNil(self.mobileMessagingInstance.currentUser.firstName)
			XCTAssertNil(self.mobileMessagingInstance.currentUser.customData(forKey: "bootsize"))
		}
	}
	
	func testThatDefaultMessageStorageCleanedUpAfterLogout() {
		weak var logoutFinished = expectation(description: "logoutFinished")
		weak var messagesReceived = expectation(description: "messagesReceived")
		let expectedMessagesCount: Int = 5
		var iterationCounter: Int = 0
		
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		_ = mobileMessagingInstance.withDefaultMessageStorage()
		MobileMessaging.defaultMessageStorage?.start()

		XCTAssertEqual(0, self.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")
		
		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo,  completion: { _ in
				iterationCounter += 1
				if iterationCounter == expectedMessagesCount {
					MobileMessaging.defaultMessageStorage!.findAllMessages() { messages in
						XCTAssertEqual(expectedMessagesCount, messages!.count)
						XCTAssertEqual(expectedMessagesCount, self.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")
						messagesReceived?.fulfill()
						MobileMessaging.logout { _ in logoutFinished?.fulfill() }
					}
				}
			})
		}
		
		waitForExpectations(timeout: 20000) { _ in
			// assert there is not any message in message storage
			MobileMessaging.defaultMessageStorage!.findAllMessages() { messages in
				XCTAssertEqual(0, messages!.count)
			}
			// internal message storage must not be cleaned up
			XCTAssertEqual(expectedMessagesCount, self.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), "Messages must be persisted properly")
		}
	}
}
