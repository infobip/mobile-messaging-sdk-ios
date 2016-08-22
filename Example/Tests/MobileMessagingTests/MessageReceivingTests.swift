//
//  MessageReceivingTests.swift
//  MobileMessaging
//
//  Created by Andrey K. on 29/02/16.
//


import SwiftyJSON
import XCTest
@testable import MobileMessaging

func backendJSONSilentMessage(messageId: String) -> String {
	return "{\"messageId\": \"\(messageId)\",\"aps\": {\"badge\": 6, \"sound\": \"default\", \"alert\": {\"title\": \"msg_title\", \"body\": \"msg_body\"}}, \"silent\": true, \"\(MMAPIKeys.kInternalData)\": {\"internalKey1\": \"internalValue1\"}, \"\(MMAPIKeys.kCustomPayload)\": {\"customKey\": \"customValue\"}}"
}

func backendJSONRegularMessage(messageId: String) -> String {
	return "{\"messageId\": \"\(messageId)\",\"aps\": {\"badge\": 6, \"sound\": \"default\", \"alert\": {\"title\": \"msg_title\", \"body\": \"msg_body\"}}, \"\(MMAPIKeys.kInternalData)\": {\"internalKey1\": \"internalValue1\"}, \"\(MMAPIKeys.kCustomPayload)\": {\"customKey\": \"customValue\"}}"
}

let jsonWithoutMessageId = "{\"foo\":\"bar\"}"

func apnsNormalMessagePayload(messageId: String) -> [NSObject: AnyObject] {
	return [
		"messageId": messageId,
		"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
		MMAPIKeys.kInternalData: ["internalKey": "internalValue"],
		MMAPIKeys.kCustomPayload: ["customKey": "customValue"]
	]
}

func apnsSilentMessagePayload(messageId: String) -> [NSObject: AnyObject] {
	return [
		"messageId": messageId,
		"aps": ["content-available": 1, "badge": 6],
		MMAPIKeys.kInternalData: ["silent" : [ "title": "msg_title", "body": "msg_body", "sound": "default"], "internalKey": "internalValue"],
		MMAPIKeys.kCustomPayload: ["customKey": "customValue"]
	]
}

func sendPushes(preparingFunc:(String) -> [NSObject: AnyObject], count: Int, receivingHandler: ([String: AnyObject]) -> Void) {
    for _ in 0..<count {
        let newMessageId = NSUUID().UUIDString
        if let payload = MMMessage(payload: preparingFunc(newMessageId))?.originalPayload {
            receivingHandler(payload)
        } else {
            XCTFail()
        }
    }
}

class MessageReceivingTests: MMTestCase {
	
	func testJSONToNSObjects() {
		let jsonstring = backendJSONRegularMessage("m1")
		let resultDict = [
							"messageId": "m1",
							"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
							MMAPIKeys.kInternalData: ["internalKey1": "internalValue1"],
							MMAPIKeys.kCustomPayload: ["customKey" : "customValue"]
						]

		
		let message = MMMessage(json: JSON.parse(jsonstring))

		XCTAssertEqual(message?.originalPayload as! [String: NSObject], resultDict)
		XCTAssertEqual(message?.customPayload as! [String: NSObject], ["customKey" : "customValue"])
		XCTAssertFalse(message!.isSilent)
	}
	
	func testSilentJSONToNSObjects() {
		let jsonstring = backendJSONSilentMessage("m1")
		let resultDict = [
			"messageId": "m1",
			"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
			"silent": 1,
			MMAPIKeys.kInternalData: ["internalKey1": "internalValue1"],
			MMAPIKeys.kCustomPayload : ["customKey" : "customValue"]
		]
		
		let message = MMMessage(json: JSON.parse(jsonstring))
		
		XCTAssertEqual(message?.originalPayload as! [String: NSObject], resultDict)
		XCTAssertEqual(message?.customPayload as! [String: NSObject], ["customKey" : "customValue"])
		XCTAssertTrue(message!.isSilent)
	}
	
	func testPayloadParsing() {
		XCTAssertNil(MMMessage(json: JSON.parse(jsonWithoutMessageId)),"Message decoding must throw with nonAPSjson")
		
		let id = NSUUID().UUIDString
		let json = JSON.parse(backendJSONRegularMessage(id))
		if let message = MMMessage(json: json) {
			XCTAssertFalse(message.isSilent)
			XCTAssertEqual(message.originalPayload["aps"]!["alert"]!!["body"], "msg_body", "Message body must be parsed")
			XCTAssertEqual(message.originalPayload["aps"]!["sound"], "default", "sound must be parsed")
			XCTAssertEqual(message.originalPayload["aps"]!["badge"], 6, "badger must be parsed")

			XCTAssertEqual(message.messageId, id, "Message Id must be parsed")
		} else {
			XCTFail("Message decoding failed")
		}
	}

    func testMessagesPersisting() {
        let expectation = expectationWithDescription("Check finished")
		let expectedMessagesCount: Int = 5
		var iterationCounter: Int = 0
		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo, newMessageReceivedCallback: nil, completion: { result in
				iterationCounter += 1
				if iterationCounter == expectedMessagesCount {
					expectation.fulfill()
				}
			})
        }
		self.waitForExpectationsWithTimeout(100, handler: { error in
			XCTAssertEqual(self.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), expectedMessagesCount, "Messages must be persisted properly")
		})
	}
	
	func testThatSilenMessagesEventWorks() {
		let expectedEventsCount: Int = 5
		var eventsCounter: Int = 0
		
		expectationForNotification(MMNotificationMessageReceived, object: nil) { (notification) -> Bool in
			if notification.userInfo?[MMNotificationKeyMessageIsSilent] as? Bool == true {
				eventsCounter += 1
			}
			return eventsCounter == expectedEventsCount
		}
		
		sendPushes(apnsSilentMessagePayload, count: expectedEventsCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo)
		}
		
		self.waitForExpectationsWithTimeout(10, handler: { error in
			XCTAssertEqual(eventsCounter, expectedEventsCount, "We should receive exact same amount of events")
		})
	}
	
	func testThatServerSilentMessageParsing() {
		
		let id = NSUUID().UUIDString
		let json = JSON.parse(backendJSONSilentMessage(id))
		if let message = MMMessage(json: json) {
			XCTAssertTrue(message.isSilent, "Message must be parsed as silent")
			XCTAssertEqual(message.messageId, id, "Message Id must be parsed")
		} else {
			XCTFail("Message decoding failed")
		}
	}
}
