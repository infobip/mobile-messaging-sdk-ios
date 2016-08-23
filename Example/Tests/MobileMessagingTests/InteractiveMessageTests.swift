//
//  InteractiveMessageTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 08.07.16.
//

import XCTest
@testable import MobileMessaging

class InteractiveMessageTests: XCTestCase {
	
	func apnsPayloadWithAllActions(categoryId: String, actionId: String) -> [NSObject: AnyObject] {
		return
			[
				"messageId": "m1",
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
		let replyExp = expectationWithDescription("Reply handler called")
		let mssExp = expectationWithDescription("Mark as Seen handler called")
		var replyResultMessageId: String?
		var markAsSeenResultMessageId: String?
		
		MMActionReply.setActionHandler { (result) in
			replyResultMessageId = result.messageId
			replyExp.fulfill()
		}
		
		MMActionMarkAsSeen.setActionHandler { (result) in
			markAsSeenResultMessageId = result.messageId
			mssExp.fulfill()
		}
		
		let actionId = "open_url"
		MMMessage.performAction(actionId, userInfo: apnsPayloadWithAllActions("category", actionId: actionId), responseInfo: nil, completionHandler: nil)
		
		self.waitForExpectationsWithTimeout(200) { err in
			XCTAssertEqual(replyResultMessageId, "m1")
			XCTAssertEqual(markAsSeenResultMessageId, "m1")
		}
	}
	
	func testHandlersNotCalledForPredefinedCategory() {
		let actionId = "reply"
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
		
		MMMessage.performAction(actionId, userInfo: apnsPayloadWithAllActions("chatMessage", actionId: actionId), responseInfo: nil, completionHandler: nil)
		
		self.waitForExpectationsWithTimeout(10, handler: nil)
	}
	
	func testReplyText() {
		let actionId = "reply"
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
			MMMessage.performAction(actionId,
			                        userInfo: apnsPayloadWithAllActions("chatMessage", actionId: actionId),
			                        responseInfo: [UIUserNotificationActionResponseTypedTextKey : replyText],
			                        completionHandler: nil)
		} else {
			MMMessage.performAction(actionId,
			                        userInfo: apnsPayloadWithAllActions("chatMessage", actionId: actionId),
			                        responseInfo: nil,
			                        completionHandler: nil)
		}
		
		self.waitForExpectationsWithTimeout(10, handler: nil)
	}
}
