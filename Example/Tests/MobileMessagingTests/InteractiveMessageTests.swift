//
//  InteractiveMessageTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 08.07.16.
//

import XCTest
@testable import MobileMessaging

class InteractiveMessageTests: XCTestCase {
	
	func apnsPayloadWithAllActions(categoryId: String, actionId: String) -> [AnyHashable: Any] {
		return
			[
				"messageId": "m1" ,
				"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "category": "\(categoryId)", "badge": 6, "sound": "default"],
				MMAPIKeys.kInternalData:
				[
					    MMAPIKeys.kInteractive:
					    [
							MMAPIKeys.kButtonActions : [
								"\(actionId)" : [
									"mark_as_seen",
									"reply"
								]
							]
						]
				],
				MMAPIKeys.kCustomPayload: ["customKey": "customValue"]
		    ]
	}

    func testHandlersCalled() {
		let replyExp = expectation(description: "Reply handler called")
		let mssExp = expectation(description: "Mark as Seen handler called")
		var replyResultMessageId: String?
		var markAsSeenResultMessageId: String?
		
		MMActionReply.setHandler { (result) in
			replyResultMessageId = result.messageId
			replyExp.fulfill()
		}
		
		MMActionMarkAsSeen.setHandler { (result) in
			markAsSeenResultMessageId = result.messageId
			mssExp.fulfill()
		}
		
		let actionId = "open_url"

		MMMessage.performAction(withIdentifier: actionId, userInfo: apnsPayloadWithAllActions(categoryId: "category", actionId: actionId), responseInfo: nil, completionHandler: nil)
		
		self.waitForExpectations(timeout: 200) { err in
			XCTAssertEqual(replyResultMessageId, "m1")
			XCTAssertEqual(markAsSeenResultMessageId, "m1")
		}
	}
	
	func testHandlersNotCalledForPredefinedCategory() {
		let actionId = "reply"

		let replyExp = expectation(description: "Reply handler called")

		MMActionReply.setHandler { (result) in
			XCTAssertEqual(result.messageId, "m1")
			replyExp.fulfill()
		}
		
		MMActionMarkAsSeen.setHandler { (result) in
			XCTFail()
		}
		
		MMActionOpenURL.setHandler { (result) in
			XCTFail()
		}
		
		MMMessage.performAction(withIdentifier: actionId, userInfo: apnsPayloadWithAllActions(categoryId: "chatMessage", actionId: actionId), responseInfo: nil, completionHandler: nil)
		self.waitForExpectations(timeout: 10, handler: nil)
	}
	
	func testReplyText() {
		let actionId = "reply"
		let replyText = "Hello world!"
		
		let replyExp = expectation(description: "Reply handler called")
		
		MMActionReply.setHandler { (result) in
			XCTAssertEqual(result.messageId, "m1")
			
			if #available(iOS 9.0, *) {
				XCTAssertEqual(result.text, replyText)
			}
			
			replyExp.fulfill()
		}
		
		MMActionMarkAsSeen.setHandler { (result) in
			XCTFail()
		}
		
		MMActionOpenURL.setHandler { (result) in
			XCTFail()
		}
		
		if #available(iOS 9.0, *) {
			MMMessage.performAction(withIdentifier: actionId,
			                        userInfo: apnsPayloadWithAllActions(categoryId: "chatMessage", actionId: actionId),
			                        responseInfo: [UIUserNotificationActionResponseTypedTextKey : replyText],
			                        completionHandler: nil)
		} else {
			MMMessage.performAction(withIdentifier: actionId,
			                        userInfo: apnsPayloadWithAllActions(categoryId: "chatMessage", actionId: actionId),
			                        responseInfo: nil,
			                        completionHandler: nil)
		}
		
		self.waitForExpectations(timeout: 10, handler: nil)
	}
}
