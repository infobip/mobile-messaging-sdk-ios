//
//  MOMessageSending.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 21.07.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
@testable import MobileMessaging

class MOMessageSending: MMTestCase {

    func testSendMOMessageSuccessfully() {
		
		let expectation = expectationWithDescription("Sending finished")

		cleanUpAndStop()
		startWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)
		
		//Precondiotions
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		let moMessage1 = MOMessage(destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey" : "customValue1"])
		let moMessage2 = MOMessage(destination: MMTestConstants.kTestCorrectApplicationCode, text: "message2", customPayload: ["customKey" : "customValue2"])

		MobileMessaging.sendMessages([moMessage1, moMessage2]) { (result) in
			XCTAssertEqual(result.resultMessages?.first?.messageId, "m1")
			XCTAssertEqual(result.resultMessages?.first?.text, "message1")
			XCTAssertEqual(result.resultMessages?.first?.destination, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertEqual(result.resultMessages?.first?.customPayload as! [String : String], ["customKey" : "customValue1"])
			XCTAssertEqual(result.resultMessages?.first?.status, MOMessageStatus.SentSuccessfully)
			
			XCTAssertEqual(result.resultMessages?.last?.messageId, "m2")
			XCTAssertEqual(result.resultMessages?.last?.text, "message2")
			XCTAssertEqual(result.resultMessages?.last?.destination, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertEqual(result.resultMessages?.first?.customPayload as! [String : String], ["customKey" : "customValue1"])
			XCTAssertEqual(result.resultMessages?.last?.status, MOMessageStatus.SentWithFailure)
			
			expectation.fulfill()
		}
		
		waitForExpectationsWithTimeout(10, handler: nil)
    }

}
