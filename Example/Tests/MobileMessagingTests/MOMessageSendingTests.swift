//
//  MOMessageSendingTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 21.07.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
@testable import MobileMessaging

class MOMessageSendingTests: MMTestCase {

    func testSendMOMessageSuccessfully() {
		
		let expectation = self.expectation(description: "Sending finished")

		cleanUpAndStop()
		startWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)
		
		//Precondiotions
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		let moMessage1 = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey" : "customValue1" as CustomPayloadSupportedTypes])
		let moMessage2 = MOMessage(messageId: "m2", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message2", customPayload: ["customKey" : "customValue2" as CustomPayloadSupportedTypes])

		MobileMessaging.sendMessages(messages: [moMessage1, moMessage2]) { (messages, error) in
			XCTAssertEqual(messages?.first?.messageId, "m1")
			XCTAssertEqual(messages?.first?.text, "message1")
			XCTAssertEqual(messages?.first?.destination, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertEqual(messages?.first?.customPayload as! [String : String], ["customKey" : "customValue1"])
			XCTAssertEqual(messages?.first?.status, MOMessageSentStatus.SentSuccessfully)
			
			XCTAssertEqual(messages?.last?.messageId, "m2")
			XCTAssertEqual(messages?.last?.text, "message2")
			XCTAssertEqual(messages?.last?.destination, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertEqual(messages?.last?.customPayload as! [String : String], ["customKey" : "customValue2"])
			XCTAssertEqual(messages?.last?.status, MOMessageSentStatus.SentWithFailure)
			
			expectation.fulfill()
		}
		
		waitForExpectations(timeout: 10, handler: nil)
    }

}
