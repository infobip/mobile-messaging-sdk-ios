//
//  DeliveryReportingTests.swift
//  MobileMessaging
//
//  Created by Ольга Королева on 09.03.16.
//

import Freddy
@testable import MobileMessaging
import XCTest

class DeliveryReportingTests: MMTestCase {
    func testSendingDeliveryStatusSuccess() {
        let expectation = expectationWithDescription("Delivery sending completed")
		
		mobileMessagingInstance.didReceiveRemoteNotification(["messageId": "m1", "supplementaryId": "m1"], newMessageReceivedCallback: {
			
			XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 1, "There must be only one stored message")
			
			}, completion: { error in
				
				XCTAssertNil(error, "Delivery reporting request failed with error")
				XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 0, "There must be not any stored message")
				expectation.fulfill()
				
		})
		
        self.waitForExpectationsWithTimeout(50, handler: nil)
    }
	
    func testSendingDeliveryStatusWrongAppIdFailure() {
		MobileMessaging.stop()
		MobileMessaging.testStartWithWrongApplicationCode()
		
        let expectation = expectationWithDescription("Delivery sending completed")
		
		mobileMessagingInstance.didReceiveRemoteNotification(["messageId": "m2", "supplementaryId": "m2"], newMessageReceivedCallback: {
			XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 1, "There must be only one stored message")
			
		}, completion: { error in
		
			XCTAssertNotNil(error, "We expect an error")
			XCTAssertEqual(error?.localizedDescription, "Invalid Application Id", "There must be a wrong application code error")
			expectation.fulfill()
			
		})

		self.waitForExpectationsWithTimeout(5000) { err in
			XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 1, "There must be only one stored message")
		}
	}
	
    func testExpiredDeliveryReportsClean() {
        let expectation = expectationWithDescription("old entities cleaned")
        let kEntityExpirationPeriod: NSTimeInterval = 7 * 24 * 60 * 60; //one week
        let messageHandler = MMMessageHandler(storage: storage, baseURL: MMTestConstants.kTestBaseURLString, applicationCode: MMTestConstants.kTestCorrectApplicationCode)
	
		messageHandler.storageContext.performBlockAndWait {
			let newMsg1 = MessageManagedObject.MR_createEntityInContext(messageHandler.storageContext)
			newMsg1.messageId = "qwerty1"
            newMsg1.supplementaryId = "qwerty1"
			newMsg1.creationDate = NSDate().dateByAddingTimeInterval(-kEntityExpirationPeriod)
			
			let newMsg2 = MessageManagedObject.MR_createEntityInContext(messageHandler.storageContext)
			newMsg2.messageId = "qwerty2"
            newMsg2.supplementaryId = "qwerty2"
			newMsg2.creationDate = NSDate().dateByAddingTimeInterval(-kEntityExpirationPeriod)
			
			messageHandler.save()
			
			XCTAssertEqual(self.nonReportedStoredMessagesCount(messageHandler.storageContext), 2, "There must be only two stored message")
		}
	
		messageHandler.evictOldMessages {
			expectation.fulfill()
		}

		self.waitForExpectationsWithTimeout(50) { error in
			XCTAssertEqual(self.nonReportedStoredMessagesCount(messageHandler.storageContext), 0, "There must be not any stored message")
		}
    }
}