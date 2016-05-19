//
//  MessageReceivingTests.swift
//  MobileMessaging
//
//  Created by Andrey K. on 29/02/16.
//


import Freddy
import XCTest
@testable import MobileMessaging

func jsonString(messageId: String) -> String {
	return "{\"aps\":{\"alert\":\"test\",\"badge\":6,\"sound\":\"default\"},\"messageId\":\"\(messageId)\"}"
}

func jsonStringAlertObject(messageId: String) -> String {
	return "{\"aps\":{\"alert\":{\"body\":\"testbody\",\"title\":\"testtitle\"},\"badge\":6,\"sound\":\"default\"},\"messageId\":\"\(messageId)\"}"
}

func jsonStringFromBackend(messageId: String) -> String {
    return "{\"body\":\"test\",\"badge\":6,\"sound\":\"default\",\"messageId\":\"\(messageId)\", \"data\": {\"key1\": \"value1\"}}"
}

let jsonWithoutMessageId = "{\"foo\":\"bar\"}"


func jsonDictionary(messageId: String) -> [NSObject: AnyObject] {
    return ["messageId": messageId, "aps": ["alert":"alerttitle", "badge": 6, "sound": "default"]]
}


func sendPushes(count: Int, receivingHandler: ([String: AnyObject]) -> Void) {
    for _ in 0..<count {
        let newMessageId = NSUUID().UUIDString
        if let payload = MMMessage(payload: jsonDictionary(newMessageId))?.payload {
            receivingHandler(payload)
        } else {
            XCTFail()
        }
    }
}

class MessageReceivingTests: MMTestCase {
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
				let json = try JSON(jsonString: jsonStringFromBackend(id))
				let message = try MMMessage(json: json)
				XCTAssertEqual(message.payload!["aps"]!["alert"]!!["body"], "test", "Message body must be parsed")
				XCTAssertEqual(message.payload!["aps"]!["sound"], "default", "sound must be parsed")
				XCTAssertEqual(message.payload!["aps"]!["badge"], 6, "badger must be parsed")
                XCTAssertEqual(message.data!, ["key1": "value1"], "data must be parsed")
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
		sendPushes(expectedMessagesCount) { userInfo in
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
}
