//
//  MessageReceivingTests.swift
//  MobileMessaging
//
//  Created by Andrey K. on 29/02/16.
//

import XCTest
@testable import MobileMessaging

let sendDateTimeMillis = 1503583689984 as Double

func backendJSONSilentMessage(messageId: String) -> String {
	return "{\"messageId\": \"\(messageId)\",\"aps\": {\"badge\": 6, \"sound\": \"default\", \"alert\": {\"title\": \"msg_title\", \"body\": \"msg_body\"}}, \"silent\": true, \"\(APNSPayloadKeys.internalData)\": {\"sendDateTime\": 1503583689984, \"internalKey1\": \"internalValue1\"}, \"\(APNSPayloadKeys.customPayload)\": {\"customKey\": \"customValue\"}}"
}

func backendJSONRegularMessage(messageId: String) -> String {
	return "{\"messageId\": \"\(messageId)\",\"aps\": {\"badge\": 6, \"sound\": \"default\", \"alert\": {\"title\": \"msg_title\", \"body\": \"msg_body\"}}, \"\(APNSPayloadKeys.internalData)\": {\"sendDateTime\": 1503583689984, \"internalKey1\": \"internalValue1\", \"atts\": [{\"url\":\"pic.url\",\"t\":\"string\"}]}, \"\(APNSPayloadKeys.customPayload)\": {\"customKey\": \"customValue\"}}"
}

let jsonWithoutMessageId = "{\"foo\":\"bar\"}"

func apnsNormalMessagePayload(_ messageId: String) -> [AnyHashable: Any] {
	return [
		"messageId": messageId,
		"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
		APNSPayloadKeys.internalData: ["sendDateTime": sendDateTimeMillis, "internalKey": "internalValue"],
		APNSPayloadKeys.customPayload: ["customKey": "customValue"]
	]
}

func apnsSilentMessagePayload(_ messageId: String) -> [AnyHashable: Any] {
	return [
		"messageId": messageId,
		"aps": ["content-available": 1, "badge": 6],
		APNSPayloadKeys.internalData: ["sendDateTime": sendDateTimeMillis, "silent" : [ "title": "msg_title", "body": "msg_body", "sound": "default"], "internalKey": "internalValue"],
		APNSPayloadKeys.customPayload: ["customKey": "customValue"]
	]
}

func sendPushes(_ preparingFunc:(String) -> [AnyHashable: Any], count: Int, receivingHandler: ([AnyHashable: Any]) -> Void) {
    for _ in 0..<count {
		let newMessageId = UUID().uuidString
		if let payload = MTMessage(payload: preparingFunc(newMessageId))?.originalPayload {
            receivingHandler(payload)
        } else {
            XCTFail()
        }
    }
}

class MessageReceivingTests: MMTestCase {
	
	func testLocalizedUserNotificationStringOrFallback() {
		XCTAssertEqual(String.localizedUserNotificationStringOrFallback(key: "LOCALIZABLE_MESSAGE_KEY", args: ["args"], fallback: "fallback"), "A localizable message with a placeholder args")
		XCTAssertEqual(String.localizedUserNotificationStringOrFallback(key: "LOCALIZABLE_MESSAGE_KEY", args: nil, 		fallback: "fallback"), "A localizable message with a placeholder %@")
		XCTAssertEqual(String.localizedUserNotificationStringOrFallback(key: "NON_EXISTENT_KEY", 		args: ["args"], fallback: "fallback"), "NON_EXISTENT_KEY")
		XCTAssertEqual(String.localizedUserNotificationStringOrFallback(key: "NON_EXISTENT_KEY", 		args: nil, 		fallback: "fallback"), "NON_EXISTENT_KEY")
		XCTAssertEqual(String.localizedUserNotificationStringOrFallback(key: nil, 						args: ["Foo"], 	fallback: "fallback"), "fallback")
	}
	
	func testMessageLocalization() {
		let jsonStr  = """
						{
							"messageId": "messageId",
							"aps": {
								"badge": 6,
								"sound": "default",
								"alert": {
									"title-loc-key": "LOCALIZABLE_MESSAGE_KEY",
									"title-loc-args": ["title args"],
									"loc-key": "LOCALIZABLE_MESSAGE_KEY",
									"loc-args": ["text args"]
								}
							}
						}
						"""
		let message = MTMessage(json: JSON.parse(jsonStr))
		XCTAssertEqual(message!.text!, "A localizable message with a placeholder text args")
		XCTAssertEqual(message!.title!, "A localizable message with a placeholder title args")
	}
	
	func testJSONToNSObjects() {
		let jsonstring = backendJSONRegularMessage(messageId: "m1")
		let resultDict = [
							"messageId": "m1",
							"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
							APNSPayloadKeys.internalData: ["sendDateTime": sendDateTimeMillis, "internalKey1": "internalValue1", InternalDataKeys.attachments: [["url": "pic.url", "t": "string"]]],
							APNSPayloadKeys.customPayload: ["customKey" : "customValue"],
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
			APNSPayloadKeys.internalData: ["sendDateTime": sendDateTimeMillis, "internalKey1": "internalValue1"],
			APNSPayloadKeys.customPayload : ["customKey" : "customValue"]
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
			XCTAssertEqual(message.contentUrl, "pic.url")
			print(Date(timeIntervalSince1970: message.sendDateTime))
			
			XCTAssertEqual(message.sendDateTime, sendDateTimeMillis/1000, accuracy: 0.0001)
		} else {
			XCTFail("Message decoding failed")
		}
	}

    func testMessagesPersisting() {
        weak var expectation = self.expectation(description: "Check finished")
		let expectedMessagesCount: Int = 5
		var iterationCounter: Int = 0
		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo,  completion: { _ in
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
	
	func testMessagesPersistingForDisabledRegistration() {
		weak var expectation = self.expectation(description: "Check finished")
		let expectedMessagesCount: Int = 5
		var iterationCounter: Int = 0
		
		MobileMessaging.disablePushRegistration { _ in
			
			sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
				
				self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo,  completion: { _ in
					DispatchQueue.main.async {
						iterationCounter += 1
						if iterationCounter == expectedMessagesCount {
							expectation?.fulfill()
						}
					}
				})
			}
			
		}
		self.waitForExpectations(timeout: 60, handler: { error in
			XCTAssertEqual(self.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 0, "There must be not any message in db, since we disabled the registration")
		})
	}

	func testThatSilentMessagesEvenWorks() {
		let expectedEventsCount: Int = 5
		var eventsCounter: Int = 0
		var messageHandlingCounter: Int = 0
		
		weak var messageHandlingFinished = self.expectation(description: "messages handling finished")
		
		expectation(forNotification: MMNotificationMessageReceived, object: nil) { (notification) -> Bool in
			if let message = notification.userInfo?[MMNotificationKeyMessage] as? MTMessage, message.isSilent == true {
				eventsCounter += 1
			}
			return eventsCounter == expectedEventsCount
		}
		
		sendPushes(apnsSilentMessagePayload, count: expectedEventsCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo, completion: { (error) in
				messageHandlingCounter += 1
				if (messageHandlingCounter == 5) {
					messageHandlingFinished?.fulfill()
				}
			})
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
	
	func testTapHandlingForInactiveApplication() {
		collectSixTappedMessages(forApplication: InactiveApplicationStub()) { tappedMessages in
		
			XCTAssertEqual(tappedMessages.count, 6)
			
			XCTAssertTrue(tappedMessages.contains(where: { (m) -> Bool in
				return m.messageId == "m1"
			}))
			
			XCTAssertTrue(tappedMessages.contains(where: { (m) -> Bool in
				return m.messageId == "m2"
			}))
			
			XCTAssertTrue(tappedMessages.contains(where: { (m) -> Bool in
				
				if let cp = m.customPayload {
					let ret = (cp as NSDictionary).isEqual(to: ["customKey": "customValue"])
					return ret
				} else {
					return false
				}
				
			}))
		}
	}
	
	func testTapHandlingForActiveApplication() {
		collectSixTappedMessages(forApplication: ActiveApplicationStub()) { tappedMessages in
			XCTAssertEqual(tappedMessages.count, 0)
		}
	}
	
	func testTapHandlerCalledIfUserInfoContainsApplicationLaunchedByNotificationKey() {
		collectSixTappedMessages(forApplication: ActiveApplicationStub(), additionalPayload: [ApplicationLaunchedByNotification_Key: true]) { (tappedMessages) in
			XCTAssertEqual(tappedMessages.count, 6)
		}
	}
	
	private func collectSixTappedMessages(forApplication application: MMApplication, additionalPayload: [AnyHashable: Any] = [:], assertionsBlock: @escaping ([MTMessage]) -> Void) {
		weak var messageReceived1 = self.expectation(description: "message received")
		weak var messageReceived2 = self.expectation(description: "message received")
		weak var messageReceived3 = self.expectation(description: "message received")
		weak var messageReceived4 = self.expectation(description: "message received")

		var tappedMessages = [MTMessage]()
		
		self.mobileMessagingInstance.application = application
		MobileMessaging.notificationTapHandler = { message in
			tappedMessages.append(message)
		}
		
		let payload1 = apnsNormalMessagePayload("m1") + additionalPayload
		let payload2 = apnsNormalMessagePayload("m2") + additionalPayload
		
		self.mobileMessagingInstance.didReceiveRemoteNotification(payload1,  completion: { _ in
			messageReceived1?.fulfill()
			
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload1,  completion: { _ in
				//FIXME: Workaround. I have to wait until all the async calls to notificationTapHandler performed, so I explicitly postpone the fulfilling.
				Thread.sleep(forTimeInterval: 1)
				messageReceived3?.fulfill()
			})
		})
		
		self.mobileMessagingInstance.didReceiveRemoteNotification(payload2,  completion: { _ in
			messageReceived2?.fulfill()
			
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload2,  completion: { _ in
				//FIXME: Workaround. I have to wait until all the async calls to notificationTapHandler performed, so I explicitly postpone the fulfilling.
				Thread.sleep(forTimeInterval: 1)
				messageReceived4?.fulfill()
			})
		})
		
		MobileMessaging.didReceiveLocalNotification(UILocalNotification.mm_localNotification(with: payload1))
		MobileMessaging.didReceiveLocalNotification(UILocalNotification.mm_localNotification(with: payload1))
		
		self.waitForExpectations(timeout: 60, handler: { error in
			assertionsBlock(tappedMessages)
		})
	}
}

extension UILocalNotification {
	class func mm_localNotification(with payload: [AnyHashable: Any]) -> UILocalNotification {
		let m = MTMessage(payload: payload)!
		let localNotification = UILocalNotification()
		localNotification.userInfo = [LocalNotificationKeys.pushPayload: payload]
		localNotification.alertBody = m.text
		localNotification.soundName = m.sound
		return localNotification
	}
}
