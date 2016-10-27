//
//  MessageStorageTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 15/09/16.
//

import XCTest
@testable import MobileMessaging

class MockMessageStorage: NSObject, MessageStorage {
	let updateMessageSentStatusHook: ((MOMessageSentStatus) -> Void)?
	
	init(updateMessageSentStatusHook: ((MOMessageSentStatus) -> Void)? = nil) {
		self.updateMessageSentStatusHook = updateMessageSentStatusHook
	}
	
	var queue: DispatchQueue {
		return DispatchQueue.main
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
		if let idx = moMessages.index(where: { $0 == messageId }) {
			return BaseMessage(messageId: moMessages[idx], direction: .MO, originalPayload: ["messageId": moMessages[idx]], createdDate: Date())
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
		weak var expectation1 = expectation(description: "Sending 1 finished")
		weak var expectation2 = expectation(description: "Sending 2 finished")
		let mockMessageStorage = MockMessageStorage()
		XCTAssertEqual(mockMessageStorage.moMessages.count, 0)
		
		MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: []).withBackendBaseURL(MMTestConstants.kTestBaseURLString).withMessageStorage(mockMessageStorage).start()
		
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		do {
			let moMessage = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey": "customValue1" as NSString])
			MobileMessaging.sendMessages([moMessage]) { (messages, error) in
				expectation1?.fulfill()
			}
		}
		
		do {
			let moMessage = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey": "customValue1" as NSString])
			MobileMessaging.sendMessages([moMessage]) { (messages, error) in
				expectation2?.fulfill()
			}
		}
		
		waitForExpectations(timeout: 10, handler: { error in
			XCTAssertEqual(mockMessageStorage.moMessages.count, 1)
		})
	}
	
	func testMOHooks() {
		cleanUpAndStop()
		var isSentSuccessfully = false
		var isSentWithFailure = false
		
		weak var expectation = self.expectation(description: "Sending finished")
		weak var expectation2 = self.expectation(description: "Sent status updated")
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
				expectation2?.fulfill()
			}
		})
		XCTAssertEqual(mockMessageStorage.moMessages.count, 0)
		
		MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: []).withBackendBaseURL(MMTestConstants.kTestBaseURLString).withMessageStorage(mockMessageStorage).start()

		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		let moMessage1 = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey": "customValue1" as NSString])
		let moMessage2 = MOMessage(messageId: "m2", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message2", customPayload: ["customKey": "customValue2" as NSString])
		
		MobileMessaging.sendMessages([moMessage1, moMessage2]) { (messages, error) in
			expectation?.fulfill()
		}
		
		waitForExpectations(timeout: 10, handler: { error in
			XCTAssertTrue(isSentSuccessfully)
			XCTAssertTrue(isSentWithFailure)
			XCTAssertEqual(mockMessageStorage.moMessages.count, 2)
			XCTAssertEqual(updateSentStatusCounter, 2)
		})
	}
	
    func testExample() {
		cleanUpAndStop()
		MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: []).withBackendBaseURL(MMTestConstants.kTestBaseURLString).withDefaultMessageStorage().start()
		
		weak var expectation1 = expectation(description: "Check finished")
		self.defaultMessageStorage?.findAllMessages { results in
			XCTAssertEqual(results?.count, 0)
			expectation1?.fulfill()
		}
		
		let expectedMessagesCount = 5
		weak var expectation2 = expectation(description: "Check finished")
		var iterationCounter: Int = 0
		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo, newMessageReceivedCallback: nil, completion: { result in
				iterationCounter += 1
				if iterationCounter == expectedMessagesCount {
					self.defaultMessageStorage?.findAllMessages { results in
						XCTAssertEqual(results?.count, expectedMessagesCount)
						expectation2?.fulfill()
					}
				}
			})
		}

		self.waitForExpectations(timeout: 100, handler: nil)
    }
	
	func testCustomStorage() {
		cleanUpAndStop()
		
		let mockMessageStorage = MockMessageStorage()
		MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: []).withBackendBaseURL(MMTestConstants.kTestBaseURLString).withMessageStorage(mockMessageStorage).start()
		
		XCTAssertEqual(mockMessageStorage.mtMessages.count, 0)
		
		let expectedMessagesCount = 5
		weak var expectation = self.expectation(description: "Check finished")
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
		
		self.waitForExpectations(timeout: 100, handler: { error in
			XCTAssertEqual(mockMessageStorage.mtMessages.count, expectedMessagesCount)
			XCTAssertEqual(self.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), expectedMessagesCount, "Messages must be persisted properly")
		})
	}
	
	
	func testQuery() {
		cleanUpAndStop()
		MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: []).withBackendBaseURL(MMTestConstants.kTestBaseURLString).withDefaultMessageStorage().start()
		
		let messageReceivingGroup = DispatchGroup()
		weak var expectation = self.expectation(description: "Check finished")
		
		do {
			let payload = apnsNormalMessagePayload("001")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload, newMessageReceivedCallback: nil, completion: { result in
				messageReceivingGroup.leave()
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("002")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload, newMessageReceivedCallback: nil, completion: { result in
				messageReceivingGroup.leave()
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("003")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload, newMessageReceivedCallback: nil, completion: { result in
				messageReceivingGroup.leave()
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("004")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload, newMessageReceivedCallback: nil, completion: { result in
				messageReceivingGroup.leave()
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("005")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload, newMessageReceivedCallback: nil, completion: { result in
				messageReceivingGroup.leave()
			})
		}
		
		messageReceivingGroup.notify(queue: DispatchQueue.main) { 
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
				
				expectation?.fulfill()
			}
		}

		self.waitForExpectations(timeout: 100, handler: nil)
	}
	
	override func tearDown() {
		self.defaultMessageStorage?.coreDataStorage?.drop()
		super.tearDown()
	}
}
