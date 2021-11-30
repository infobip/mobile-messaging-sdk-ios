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
        MMTestCase.startWithCorrectApplicationCode()
        
        weak var expectation = self.expectation(description: "Delivery sending completed")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": "m1"], completion: { result in
				XCTAssertNil(result.error, "Delivery reporting request failed with error")
				XCTAssertEqual(MMTestCase.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 0, "There must be not any stored message")
				expectation?.fulfill()
			}
		)
		
        self.waitForExpectations(timeout: 60, handler: nil)
    }
	
    func testSendingDeliveryStatusWrongAppIdFailure() {
		MMTestCase.startWithWrongApplicationCode()
		
        weak var expectation = self.expectation(description: "Delivery sending completed")
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps":["key":"value"], "messageId": "m2"], completion: { result in
		
			XCTAssertNotNil(result.error)
			XCTAssertEqual(result.error?.localizedDescription, "Invalid Application Id")
			XCTAssertEqual(result.error?.userInfo[Consts.APIKeys.errorMessageId] as? String, "1")
			expectation?.fulfill()
		})

		self.waitForExpectations(timeout: 60) { _ in
			XCTAssertEqual(MMTestCase.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 1, "There must be only one stored message")
		}
	}
}
