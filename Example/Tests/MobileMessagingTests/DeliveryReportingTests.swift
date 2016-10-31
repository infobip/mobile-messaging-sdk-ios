//
//  DeliveryReportingTests.swift
//  MobileMessaging
//
//  Created by okoroleva on 09.03.16.
//

@testable import MobileMessaging
import XCTest

class DeliveryReportingTests: MMTestCase {
    func testSendingDeliveryStatusSuccess() {
	
        weak var expectation = self.expectation(description: "Delivery sending completed")
		
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": "m1"], newMessageReceivedCallback: { _ in
			
			XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 1, "There must be only one stored message")
			
			}, completion: { error in
				
				XCTAssertNil(error, "Delivery reporting request failed with error")
				XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 0, "There must be not any stored message")
				expectation?.fulfill()
				
			})
		
        self.waitForExpectations(timeout: 60, handler: nil)
    }
	
    func testSendingDeliveryStatusWrongAppIdFailure() {
		cleanUpAndStop()
		startWithWrongApplicationCode()
		
        weak var expectation = self.expectation(description: "Delivery sending completed")
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.didReceiveRemoteNotification(["aps":["key":"value"], "messageId": "m2"], newMessageReceivedCallback: { _ in
			XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 1, "There must be only one stored message")
			
		}, completion: { error in
		
			XCTAssertNotNil(error)
			XCTAssertEqual(error?.localizedDescription, "Invalid Application Id")
			XCTAssertEqual(error?.userInfo[MMAPIKeys.kErrorMessageId] as? String, "1")
			expectation?.fulfill()
		})

		self.waitForExpectations(timeout: 60) { _ in
			XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 1, "There must be only one stored message")
		}
	}
	
    func testExpiredDeliveryReportsClean() {
        weak var evictionExpectation = self.expectation(description: "Old messages evicted")
        let kEntityExpirationPeriod: TimeInterval = 7 * 24 * 60 * 60; //one week
		let ctx = self.storage.mainThreadManagedObjectContext!
		
		mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": "qwerty1"], newMessageReceivedCallback: nil, completion: { err in
            DispatchQueue.main.async {
                XCTAssertEqual(self.allStoredMessagesCount(ctx), 1, "There must be a stored message")
                let messageHandler = self.mobileMessagingInstance.messageHandler!
                messageHandler.evictOldMessages(kEntityExpirationPeriod) {
                    XCTAssertEqual(self.allStoredMessagesCount(ctx), 1, "There is no messages to evict, there must be a stored message")
                    
                    // this is a workaround: negative age used to simulate that eviction happens in future so that our messages considered as old
                    messageHandler.evictOldMessages(-kEntityExpirationPeriod) {
                        evictionExpectation?.fulfill()
                    }
                }
            }
		})

		self.waitForExpectations(timeout: 60) { _ in
			XCTAssertEqual(self.allStoredMessagesCount(ctx), 0, "There must be not any stored message")
		}
    }
}
