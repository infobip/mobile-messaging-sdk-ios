//
//  MessageReceivingTests.swift
//  MobileMessaging
//
//  Created by Andrey K. on 29/02/16.
//


import Freddy
import XCTest
@testable import MobileMessaging

func backendJSONSilentMessage(messageId: String) -> String {
	return "{\"messageId\": \"\(messageId)\",\"aps\": {\"badge\": 6, \"sound\": \"default\", \"alert\": {\"title\": \"msg_title\", \"body\": \"msg_body\"}}, \"silent\": true, \"internalData\": {\"internalKey1\": \"internalValue1\"}, \"\(MMAPIKeys.kAppData)\": {\"customKey\": \"customValue\"}}"
}

func backendJSONRegularMessage(messageId: String) -> String {
	return "{\"messageId\": \"\(messageId)\",\"aps\": {\"badge\": 6, \"sound\": \"default\", \"alert\": {\"title\": \"msg_title\", \"body\": \"msg_body\"}}, \"internalData\": {\"internalKey1\": \"internalValue1\"}, \"\(MMAPIKeys.kAppData)\": {\"customKey\": \"customValue\"}}"
}

let jsonWithoutMessageId = "{\"foo\":\"bar\"}"

func apnsNormalMessagePayload(messageId: String) -> [NSObject: AnyObject] {
	return [
		"messageId": messageId,
		"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
		"internalData": ["internalKey": "internalValue"],
		"customKey" : "customValue"
	]
}

func apnsSilentMessagePayload(messageId: String) -> [NSObject: AnyObject] {
	return [
		"messageId": messageId,
		"aps": ["content-available": 1, "badge": 6],
		"internalData": ["silent" : [ "title": "msg_title", "body": "msg_body", "sound": "default"], "internalKey": "internalValue"],
		"customKey" : "customValue"
	]
}


func sendPushes(preparingFunc:(String) -> [NSObject: AnyObject], count: Int, receivingHandler: ([String: AnyObject]) -> Void) {
    for _ in 0..<count {
        let newMessageId = NSUUID().UUIDString
        if let payload = MMMessage(payload: preparingFunc(newMessageId))?.payload {
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
							"internalData": ["internalKey1": "internalValue1"],
							MMAPIKeys.kAppData : ["customKey" : "customValue"]
						]
		var message: MMMessage?
		if let json = try? JSON(jsonString: jsonstring) {
			message = try? MMMessage(json: json)
		}
		XCTAssertEqual(message?.payload as! [String: NSObject], resultDict)
		XCTAssertEqual(message?.appData as! [String: NSObject], ["customKey" : "customValue"])
		XCTAssertFalse(message!.isSilent)
	}
	
	func testSilentJSONToNSObjects() {
		let jsonstring = backendJSONSilentMessage("m1")
		let resultDict = [
			"messageId": "m1",
			"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
			"silent": 1,
			"internalData": ["internalKey1": "internalValue1"],
			MMAPIKeys.kAppData : ["customKey" : "customValue"]
		]
		var message: MMMessage?
		if let json = try? JSON(jsonString: jsonstring) {
			message = try? MMMessage(json: json)
		}
		XCTAssertEqual(message?.payload as! [String: NSObject], resultDict)
		XCTAssertEqual(message?.appData as! [String: NSObject], ["customKey" : "customValue"])
		XCTAssertTrue(message!.isSilent)
	}
	
	func testPayloadParsing() {
		do {
			do {
				let json = try JSON(jsonString: jsonWithoutMessageId)
				let _ = try MMMessage(json: json)
				XCTFail("Message decoding must throw with nonAPSjson")
			} catch {
				XCTAssertTrue(true)
			}
			
			do {
				let id = NSUUID().UUIDString
				let json = try JSON(jsonString: backendJSONRegularMessage(id))
				let message = try MMMessage(json: json)
				XCTAssertFalse(message.isSilent)
				XCTAssertEqual(message.payload!["aps"]!["alert"]!!["body"], "msg_body", "Message body must be parsed")
				XCTAssertEqual(message.payload!["aps"]!["sound"], "default", "sound must be parsed")
				XCTAssertEqual(message.payload!["aps"]!["badge"], 6, "badger must be parsed")

				XCTAssertEqual(message.messageId, id, "Message Id must be parsed")
			}
		} catch {
			XCTFail("JSON string encoding failed")
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
		do {
			do {
				let id = NSUUID().UUIDString
				let json = try JSON(jsonString: backendJSONSilentMessage(id))
				let message = try MMMessage(json: json)
				XCTAssertTrue(message.isSilent, "Message must be parsed as silent")
				XCTAssertEqual(message.messageId, id, "Message Id must be parsed")
			}
		} catch {
			XCTFail("JSON string encoding failed")
		}
	}
}
