//
//  MessageStorageTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 15/09/16.
//

import XCTest
@testable import MobileMessaging

class MockMessageStorage: NSObject, MessageStorage {
	let updateMessageSentStatusHook: (MOMessageSentStatus -> Void)?
	
	init(updateMessageSentStatusHook: (MOMessageSentStatus -> Void)? = nil) {
		self.updateMessageSentStatusHook = updateMessageSentStatusHook
	}
	
	var queue: dispatch_queue_t {
		return dispatch_get_main_queue()
	}
	var mtMessages = [String]()
	var moMessages = [String]()
	func insert(incoming messages: [MTMessage]) {
		messages.forEach { (message) in
			self.mtMessages.append(message.messageId)
		}
	}
	func insert(outgoing messages: [MOMessage]) {
		messages.forEach { (message) in
			self.moMessages.append(message.messageId)
		}
	}
	func findMessage(withId messageId: MessageId) -> BaseMessage? {
		if let idx = moMessages.indexOf({ $0 == messageId }) {
			return BaseMessage(messageId: moMessages[idx], direction: .MO, originalPayload: ["messageId": moMessages[idx]], createdDate: NSDate())
		} else {
			return nil
		}
	}
	func update(deliveryReportStatus isDelivered: Bool, for messageId: MessageId) {
		
	}
	func update(messageSeenStatus status: MMSeenStatus, for messageId: MessageId) {
		
	}
	func update(messageSentStatus status: MOMessageSentStatus, for messageId: MessageId) {
		updateMessageSentStatusHook?(status)
	}
	func start() {
		
	}
	func stop() {
		
	}
}

class MessageStorageTests: MMTestCase {
	
	var defaultMessageStorage: MMDefaultMessageStorage? {
		return self.mobileMessagingInstance.messageStorage as? MMDefaultMessageStorage
	}
	
	func testMODuplication() {
		cleanUpAndStop()
		let expectation1 = expectationWithDescription("Sending 1 finished")
		let expectation2 = expectationWithDescription("Sending 2 finished")
		let mockMessageStorage = MockMessageStorage()
		XCTAssertEqual(mockMessageStorage.moMessages.count, 0)
		
		MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: .None).withBackendBaseURL(MMTestConstants.kTestBaseURLString).withMessageStorage(mockMessageStorage).start()
		
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		do {
			let moMessage = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey" : "customValue1"])
			MobileMessaging.sendMessages([moMessage]) { (messages, error) in
				expectation1.fulfill()
			}
		}
		
		do {
			let moMessage = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey" : "customValue1"])
			MobileMessaging.sendMessages([moMessage]) { (messages, error) in
				expectation2.fulfill()
			}
		}
		
		waitForExpectationsWithTimeout(5, handler: { error in
			XCTAssertEqual(mockMessageStorage.moMessages.count, 1)
		})
	}
	
	func testMOHooks() {
		cleanUpAndStop()
		var isSentSuccessfully = false
		var isSentWithFailure = false
		
		let expectation = expectationWithDescription("Sending finished")
		let expectation2 = expectationWithDescription("Sent status updated")
		var updateSentStatusCounter = 0
		let mockMessageStorage = MockMessageStorage(updateMessageSentStatusHook: { status in
			updateSentStatusCounter += 1
			
			switch status {
			case .SentSuccessfully:
				isSentSuccessfully = true
			case .SentWithFailure:
				isSentWithFailure = true
			default:
				break
			}
			
			if updateSentStatusCounter == 2 {
				expectation2.fulfill()
			}
		})
		XCTAssertEqual(mockMessageStorage.moMessages.count, 0)
		
		MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: .None).withBackendBaseURL(MMTestConstants.kTestBaseURLString).withMessageStorage(mockMessageStorage).start()

		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		let moMessage1 = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey" : "customValue1"])
		let moMessage2 = MOMessage(messageId: "m2", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message2", customPayload: ["customKey" : "customValue2"])
		
		MobileMessaging.sendMessages([moMessage1, moMessage2]) { (messages, error) in
			expectation.fulfill()
		}
		
		waitForExpectationsWithTimeout(5, handler: { error in
			XCTAssertTrue(isSentSuccessfully)
			XCTAssertTrue(isSentWithFailure)
			XCTAssertEqual(mockMessageStorage.moMessages.count, 2)
			XCTAssertEqual(updateSentStatusCounter, 2)
		})
	}
	
    func testExample() {
		cleanUpAndStop()
		MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: .None).withBackendBaseURL(MMTestConstants.kTestBaseURLString).withDefaultMessageStorage().start()
		
		let expectation1 = expectationWithDescription("Check finished")
		self.defaultMessageStorage?.findAllMessages { results in
			XCTAssertEqual(results?.count, 0)
			expectation1.fulfill()
		}
		
		let expectedMessagesCount = 5
		let expectation2 = expectationWithDescription("Check finished")
		var iterationCounter: Int = 0
		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo, newMessageReceivedCallback: nil, completion: { result in
				iterationCounter += 1
				if iterationCounter == expectedMessagesCount {
					self.defaultMessageStorage?.findAllMessages { results in
						XCTAssertEqual(results?.count, expectedMessagesCount)
						expectation2.fulfill()
					}
				}
			})
		}

		self.waitForExpectationsWithTimeout(100, handler: nil)
    }
	
	func testCustomStorage() {
		cleanUpAndStop()
		
		let mockMessageStorage = MockMessageStorage()
		MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: .None).withBackendBaseURL(MMTestConstants.kTestBaseURLString).withMessageStorage(mockMessageStorage).start()
		
		XCTAssertEqual(mockMessageStorage.mtMessages.count, 0)
		
		let expectedMessagesCount = 5
		let expectation = expectationWithDescription("Check finished")
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
			XCTAssertEqual(mockMessageStorage.mtMessages.count, expectedMessagesCount)
			XCTAssertEqual(self.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), expectedMessagesCount, "Messages must be persisted properly")
		})
	}
	
	
	func testQuery() {
		cleanUpAndStop()
		MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: .None).withBackendBaseURL(MMTestConstants.kTestBaseURLString).withDefaultMessageStorage().start()
		
		let messageReceivingGroup = dispatch_group_create()
		let expectation = expectationWithDescription("Check finished")
		
		do {
			let payload = apnsNormalMessagePayload("001")
			dispatch_group_enter(messageReceivingGroup)
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload, newMessageReceivedCallback: nil, completion: { result in
				dispatch_group_leave(messageReceivingGroup)
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("002")
			dispatch_group_enter(messageReceivingGroup)
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload, newMessageReceivedCallback: nil, completion: { result in
				dispatch_group_leave(messageReceivingGroup)
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("003")
			dispatch_group_enter(messageReceivingGroup)
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload, newMessageReceivedCallback: nil, completion: { result in
				dispatch_group_leave(messageReceivingGroup)
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("004")
			dispatch_group_enter(messageReceivingGroup)
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload, newMessageReceivedCallback: nil, completion: { result in
				dispatch_group_leave(messageReceivingGroup)
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("005")
			dispatch_group_enter(messageReceivingGroup)
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload, newMessageReceivedCallback: nil, completion: { result in
				dispatch_group_leave(messageReceivingGroup)
			})
		}
		
		
		dispatch_group_notify(messageReceivingGroup, dispatch_get_main_queue()) {
			let q = Query()
			let fetchLimit = 2
			q.skip = 1
			q.limit = fetchLimit
			let sort = NSSortDescriptor(key: "messageId", ascending: false)
			q.sortDescriptors = [sort]
			q.predicate = NSPredicate(format: "messageId IN %@", ["001", "002", "003", "004"])
			self.defaultMessageStorage?.findMessages(withQuery: q) { results in
				let msg1 = results?.first!
				let msg2 = results?.last!
				XCTAssertEqual(results?.count, fetchLimit)
				XCTAssertEqual(msg1?.messageId, "003")
				XCTAssertEqual(msg2?.messageId, "002")
				
				expectation.fulfill()
			}
		}
		
		self.waitForExpectationsWithTimeout(100, handler: nil)
	}
	
	override func tearDown() {
		self.defaultMessageStorage?.coreDataStorage?.drop()
		super.tearDown()
	}
}
