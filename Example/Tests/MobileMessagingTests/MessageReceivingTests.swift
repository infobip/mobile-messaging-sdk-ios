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
	return "{\"messageId\": \"\(messageId)\",\"aps\": {\"badge\": 6, \"sound\": \"default\", \"alert\": {\"title\": \"msg_title\", \"body\": \"msg_body\"}}, \"silent\": true, \"\(APNSPayloadKeys.kInternalData)\": {\"internalKey1\": \"internalValue1\"}, \"\(APNSPayloadKeys.kCustomPayload)\": {\"customKey\": \"customValue\"}}"
}

func backendJSONRegularMessage(messageId: String) -> String {
	return "{\"messageId\": \"\(messageId)\",\"aps\": {\"badge\": 6, \"sound\": \"default\", \"alert\": {\"title\": \"msg_title\", \"body\": \"msg_body\"}}, \"\(APNSPayloadKeys.kInternalData)\": {\"internalKey1\": \"internalValue1\"}, \"\(APNSPayloadKeys.kCustomPayload)\": {\"customKey\": \"customValue\"}}"
}

let jsonWithoutMessageId = "{\"foo\":\"bar\"}"

func apnsNormalMessagePayload(_ messageId: String) -> [AnyHashable: Any] {
	return [
		"messageId": messageId,
		"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
		APNSPayloadKeys.kInternalData: ["internalKey": "internalValue"],
		APNSPayloadKeys.kCustomPayload: ["customKey": "customValue"]
	]
}

func apnsSilentMessagePayload(_ messageId: String) -> [AnyHashable: Any] {
	return [
		"messageId": messageId,
		"aps": ["content-available": 1, "badge": 6],
		APNSPayloadKeys.kInternalData: ["silent" : [ "title": "msg_title", "body": "msg_body", "sound": "default"], "internalKey": "internalValue"],
		APNSPayloadKeys.kCustomPayload: ["customKey": "customValue"]
	]
}

func sendPushes(_ preparingFunc:(String) -> [AnyHashable: Any], count: Int, receivingHandler: ([AnyHashable: Any]) -> Void) {
    for _ in 0..<count {
		let newMessageId = UUID().uuidString
		if let payload = MTMessage(payload: preparingFunc(newMessageId), createdDate: Date())?.originalPayload {
            receivingHandler(payload)
        } else {
            XCTFail()
        }
    }
}

class MessageReceivingTests: MMTestCase {
	
	func testJSONToNSObjects() {
		let jsonstring = backendJSONRegularMessage(messageId: "m1")
		let resultDict = [
							"messageId": "m1",
							"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
							APNSPayloadKeys.kInternalData: ["internalKey1": "internalValue1"],
							APNSPayloadKeys.kCustomPayload: ["customKey" : "customValue"]
						] as APNSPayload
		let message = MTMessage(json: JSON.parse(jsonstring))
		
		XCTAssertEqual(message!.originalPayload as NSDictionary, resultDict as NSDictionary)
		XCTAssertEqual(message!.customPayload! as NSDictionary, ["customKey" : "customValue"] as NSDictionary)
		XCTAssertFalse(message!.isSilent)
	}
	
	func testSilentJSONToNSObjects() {
		let jsonstring = backendJSONSilentMessage(messageId: "m1")
		let resultDict: StringKeyPayload = [
			"messageId": "m1",
			"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
			"silent": 1,
			APNSPayloadKeys.kInternalData: ["internalKey1": "internalValue1"],
			APNSPayloadKeys.kCustomPayload : ["customKey" : "customValue"]
		]
		
		let message = MTMessage(json: JSON.parse(jsonstring))
		
		XCTAssertEqual(message!.originalPayload as NSDictionary, resultDict as NSDictionary)
		XCTAssertEqual(message!.customPayload! as NSDictionary, ["customKey" : "customValue"] as NSDictionary)
		XCTAssertTrue(message!.isSilent)
	}
	
	func testPayloadParsing() {
		XCTAssertNil(MTMessage(json: JSON.parse(jsonWithoutMessageId)),"Message decoding must throw with nonAPSjson")
		
		let id = UUID().uuidString
		let json = JSON.parse(backendJSONRegularMessage(messageId: id))
		if let message = MTMessage(json: json) {
			XCTAssertFalse(message.isSilent)
			let origPayload = message.originalPayload["aps"] as! StringKeyPayload
			XCTAssertEqual((origPayload["alert"] as! StringKeyPayload)["body"] as! String, "msg_body", "Message body must be parsed")
			XCTAssertEqual(origPayload["sound"] as! String, "default", "sound must be parsed")
			XCTAssertEqual(origPayload["badge"] as! Int, 6, "badger must be parsed")

			XCTAssertEqual(message.messageId, id, "Message Id must be parsed")
		} else {
			XCTFail("Message decoding failed")
		}
	}

    func testMessagesPersisting() {
        weak var expectation = self.expectation(description: "Check finished")
		let expectedMessagesCount: Int = 5
		var iterationCounter: Int = 0
		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo, newMessageReceivedCallback: nil, completion: { result in
				DispatchQueue.main.async {
					iterationCounter += 1
					if iterationCounter == expectedMessagesCount {
						expectation?.fulfill()
					}
				}
			})
        }
		self.waitForExpectations(timeout: 60, handler: { error in
			XCTAssertEqual(self.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), expectedMessagesCount, "Messages must be persisted properly")
		})
	}
	
	func testThatSilentMessagesEvenWorks() {
		let expectedEventsCount: Int = 5
		var eventsCounter: Int = 0
		
		expectation(forNotification: MMNotificationMessageReceived, object: nil) { (notification) -> Bool in
			if let message = notification.userInfo?[MMNotificationKeyMessage] as? MTMessage, message.isSilent == true {
				eventsCounter += 1
			}
			return eventsCounter == expectedEventsCount
		}
		
		sendPushes(apnsSilentMessagePayload, count: expectedEventsCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo)
		}
		
		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertEqual(eventsCounter, expectedEventsCount, "We should receive exact same amount of events")
		})
	}
	
	func testThatServerSilentMessageParsing() {
		
		let id = UUID().uuidString
		let json = JSON.parse(backendJSONSilentMessage(messageId: id))
		if let message = MTMessage(json: json) {
			XCTAssertTrue(message.isSilent, "Message must be parsed as silent")
			XCTAssertEqual(message.messageId, id, "Message Id must be parsed")
		} else {
			XCTFail("Message decoding failed")
		}
	}
}
