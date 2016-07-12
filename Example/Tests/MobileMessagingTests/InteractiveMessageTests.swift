//
//  InteractiveMessageTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 08.07.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
@testable import MobileMessaging

class InteractiveMessageTests: XCTestCase {
	
	func messageWithAllActions(categoryId: String, buttonId: String) -> [NSObject: AnyObject] {
		return
			[
				"messageId": "m1",
				"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "category": "\(categoryId)", "badge": 6, "sound": "default"],
				MMAPIKeys.kInternalData:
				[
					    MMAPIKeys.kInteractive:
					    [
							MMAPIKeys.kButtonActions : [ "\(buttonId)" : ["mark_as_seen", ["open_url":"http://www.google.com"], "reply"]]
						]
				],
				MMAPIKeys.kCustomPayload: ["customKey": "customValue"]
		    ]
	}

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testHandlersCalled() {
		let buttonId = "apply"
		
		let replyExp = expectationWithDescription("Reply handler called")
		let mssExp = expectationWithDescription("Mark as Seen handler called")
		let urlExp = expectationWithDescription("Open URL handler called")
		
		MMActionReply.setActionHandler { (result) in
			XCTAssertEqual(result.messageId, "m1")
			replyExp.fulfill()
		}
		
		MMActionMarkAsSeen.setActionHandler { (result) in
			XCTAssertEqual(result.messageId, "m1")
			mssExp.fulfill()
		}
		
		MMActionOpenURL.setActionHandler { (result) in
			XCTAssertEqual(result.messageId, "m1")
			XCTAssertEqual(result.url.absoluteString, "http://www.google.com")
			urlExp.fulfill()
		}
		
		MMMessage.performAction(buttonId, userInfo: messageWithAllActions("category", buttonId: buttonId), responseInfo: nil, completionHandler: nil)
		
		self.waitForExpectationsWithTimeout(10, handler: nil)
	}
	
	func testHandlersNotCalledForPredefinedCategory() {
		let buttonId = "reply"
		let replyExp = expectationWithDescription("Reply handler called")

		MMActionReply.setActionHandler { (result) in
			XCTAssertEqual(result.messageId, "m1")
			replyExp.fulfill()
		}
		
		MMActionMarkAsSeen.setActionHandler { (result) in
			XCTFail()
		}
		
		MMActionOpenURL.setActionHandler { (result) in
			XCTFail()
		}
		
		MMMessage.performAction(buttonId, userInfo: messageWithAllActions("chatMessage", buttonId: buttonId), responseInfo: nil, completionHandler: nil)
		
		self.waitForExpectationsWithTimeout(10, handler: nil)
	}
	
	func testReplyText() {
		let buttonId = "reply"
		let replyText = "Hello world!"
		
		let replyExp = expectationWithDescription("Reply handler called")
		
		MMActionReply.setActionHandler { (result) in
			XCTAssertEqual(result.messageId, "m1")
			
			if #available(iOS 9.0, *) {
				XCTAssertEqual(result.text, replyText)
			}
			
			replyExp.fulfill()
		}
		
		MMActionMarkAsSeen.setActionHandler { (result) in
			XCTFail()
		}
		
		MMActionOpenURL.setActionHandler { (result) in
			XCTFail()
		}
		
		if #available(iOS 9.0, *) {
			MMMessage.performAction(buttonId,
			                        userInfo: messageWithAllActions("chatMessage", buttonId: buttonId),
			                        responseInfo: [UIUserNotificationActionResponseTypedTextKey : replyText],
			                        completionHandler: nil)
		} else {
			MMMessage.performAction(buttonId,
			                        userInfo: messageWithAllActions("chatMessage", buttonId: buttonId),
			                        responseInfo: nil,
			                        completionHandler: nil)
		}
		
		self.waitForExpectationsWithTimeout(10, handler: nil)
	}
}
