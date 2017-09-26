//
//  MessageStorageTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 15/09/16.
//

import XCTest
import UserNotifications
@testable import MobileMessaging

class MessageStorageStub: NSObject, MessageStorage {
	let updateMessageSentStatusHook: ((MOMessageSentStatus) -> Void)?
	
	init(updateMessageSentStatusHook: ((MOMessageSentStatus) -> Void)? = nil) {
		self.updateMessageSentStatusHook = updateMessageSentStatusHook
	}
	
	var queue: DispatchQueue {
		return DispatchQueue.main
	}
	var mtMessages = [MTMessage]()
	var moMessages = [MOMessage]()
	func insert(incoming messages: [MTMessage], completion: @escaping () -> Void) {
		messages.forEach { (message) in
			self.mtMessages.append(message)
		}
		completion()
	}
	func insert(outgoing messages: [MOMessage], completion: @escaping () -> Void) {
		messages.forEach { (message) in
			self.moMessages.append(message)
		}
		completion()
	}
	func findMessage(withId messageId: MessageId) -> BaseMessage? {
		if let idx = moMessages.index(where: { $0.messageId == messageId }) {
			return BaseMessage(messageId: moMessages[idx].messageId, direction: .MO, originalPayload: ["messageId": moMessages[idx].messageId])
		} else {
			return nil
		}
	}
	func update(deliveryReportStatus isDelivered: Bool, for messageId: MessageId, completion: @escaping () -> Void) {
		completion()
	}
	func update(messageSeenStatus status: MMSeenStatus, for messageId: MessageId, completion: @escaping () -> Void) {
		completion()
	}
	func update(messageSentStatus status: MOMessageSentStatus, for messageId: MessageId, completion: @escaping () -> Void) {
		updateMessageSentStatusHook?(status)
		completion()
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
		let messageStorageStub = MessageStorageStub()
		XCTAssertEqual(messageStorageStub.moMessages.count, 0)
		stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withMessageStorage(messageStorageStub).start()
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		do {
			let moMessage = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey": "customValue1" as NSString], composedDate: Date())
			MobileMessaging.sendMessages([moMessage]) { (messages, error) in
				expectation1?.fulfill()
			}
		}
		
		do {
			let moMessage = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey": "customValue1" as NSString], composedDate: Date())
			MobileMessaging.sendMessages([moMessage]) { (messages, error) in
				expectation2?.fulfill()
			}
		}
		
		waitForExpectations(timeout: 60, handler: { error in
			XCTAssertEqual(messageStorageStub.moMessages.count, 1)
		})
	}
	
	func testMOHooks() {
		cleanUpAndStop()
		var isSentSuccessfully = false
		var isSentWithFailure = false
		
		weak var expectation = self.expectation(description: "Sending finished")
		weak var expectation2 = self.expectation(description: "Sent status updated")
		var updateSentStatusCounter = 0
		let messageStorageStub = MessageStorageStub(updateMessageSentStatusHook: { status in
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
		XCTAssertEqual(messageStorageStub.moMessages.count, 0)
		
		stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withMessageStorage(messageStorageStub).start()

		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
        let moMessage1 = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey": "customValue1" as NSString], composedDate: Date(), bulkId: "bulkId1", initialMessageId: "initialMessageId1")
		let moMessage2 = MOMessage(messageId: "m2", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message2", customPayload: ["customKey": "customValue2" as NSString], composedDate: Date(), bulkId: "bulkId2", initialMessageId: "initialMessageId2")
		
		MobileMessaging.sendMessages([moMessage1, moMessage2]) { (messages, error) in
			expectation?.fulfill()
		}
		
		waitForExpectations(timeout: 10, handler: { error in
			XCTAssertTrue(isSentSuccessfully)
			XCTAssertTrue(isSentWithFailure)
			XCTAssertEqual(messageStorageStub.moMessages.count, 2)
			XCTAssertEqual(updateSentStatusCounter, 2)
		})
	}
	
    func testDefaultStoragePersistingAndFetching() {
		cleanUpAndStop()
		
		stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withDefaultMessageStorage().start()
		
		weak var expectation1 = expectation(description: "Check finished")
		self.defaultMessageStorage?.findAllMessages { results in
			XCTAssertEqual(results?.count, 0)
			expectation1?.fulfill()
		}
		
		let expectedMessagesCount = 5
		weak var expectation2 = expectation(description: "Check finished")
		
		var iterationCounter: Int = 0
		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo, completion: { _ in
				
				DispatchQueue.main.async {
					iterationCounter += 1
				
					if iterationCounter == expectedMessagesCount {
						self.defaultMessageStorage?.findAllMessages { results in
							XCTAssertEqual(results?.count, expectedMessagesCount)
							expectation2?.fulfill()
						}
					}
				}
			})
		}

		self.waitForExpectations(timeout: 60, handler: nil)
    }
	
	func testCustomPersistingAndFetching() {
		cleanUpAndStop()
		
		let messageStorageStub = MessageStorageStub()
		
		stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withMessageStorage(messageStorageStub).start()
		
		XCTAssertEqual(messageStorageStub.mtMessages.count, 0)
		
		let expectedMessagesCount = 5
		weak var expectation = self.expectation(description: "Check finished")
		var iterationCounter: Int = 0
		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInfo, completion: { _ in
				DispatchQueue.main.async {
					iterationCounter += 1
					if iterationCounter == expectedMessagesCount {
						expectation?.fulfill()
					}
				}
			})
		}
		
		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertEqual(messageStorageStub.mtMessages.count, expectedMessagesCount)
			XCTAssertEqual(self.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), expectedMessagesCount, "Messages must be persisted properly")
		})
	}
	
	
	func testQuery() {
		cleanUpAndStop()

		stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withDefaultMessageStorage().start()
		
		let messageReceivingGroup = DispatchGroup()
		weak var expectation = self.expectation(description: "Check finished")
		
		do {
			let payload = apnsNormalMessagePayload("001")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
				messageReceivingGroup.leave()
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("002")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
				messageReceivingGroup.leave()
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("003")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
				messageReceivingGroup.leave()
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("004")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
				messageReceivingGroup.leave()
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("005")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(payload,  completion: { _ in
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

		self.waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testThatMessageStorageIsBeingPopulatedWithNotificationExtensionHandledMessages() {
		
		guard #available(iOS 10.0, *) else {
			return
		}
		
		cleanUpAndStop()
		
		let content = UNMutableNotificationContent()
		content.userInfo = [
			"messageId": "mid1",
			"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default", "mutable-content": 1]
		]
		let request = UNNotificationRequest(identifier: "id1", content: content, trigger: nil)
		let contentHandler: (UNNotificationContent) -> Void = { content in
			
		}
		let notificationExtensionStorageStub = NotificationExtensionMessageStorageStub(applicationCode: "appCode", appGroupId: "groupId")!
		

		MobileMessagingNotificationServiceExtension.startWithApplicationCode("appCode", appGroupId: "groupId")
		MobileMessagingNotificationServiceExtension.sharedInstance?.deliveryReporter = SuccessfullDeliveryReporterStub(applicationCode: "appCode", baseUrl: "groupId")
		MobileMessagingNotificationServiceExtension.sharedInstance?.sharedNotificationExtensionStorage = notificationExtensionStorageStub
		MobileMessagingNotificationServiceExtension.didReceive(request, withContentHandler: contentHandler)
		
		XCTAssertEqual(notificationExtensionStorageStub.retrieveMessages().count, 1)
		let firstMessage = notificationExtensionStorageStub.retrieveMessages().first
		XCTAssertNotNil(firstMessage!.deliveryReportedDate)
		XCTAssertTrue(firstMessage!.isDeliveryReportSent)
		
		// starting the SDK
		let messageStorageStub = MessageStorageStub()
		XCTAssertEqual(messageStorageStub.mtMessages.count, 0)
		
		let mm = stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!.withMessageStorage(messageStorageStub)
		mm.sharedNotificationExtensionStorage = notificationExtensionStorageStub
		mm.start()
		mm.sync()
		
		weak var expectation = self.expectation(description: "")
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
			XCTAssertEqual(notificationExtensionStorageStub.retrieveMessages().count, 0)
			expectation?.fulfill()
		}
		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertEqual(messageStorageStub.mtMessages.count, 1)
		})
	}
	
	override func tearDown() {
		self.defaultMessageStorage?.coreDataStorage?.drop()
		super.tearDown()
	}
}

class SuccessfullDeliveryReporterStub: DeliveryReporting {
	required init(applicationCode: String, baseUrl: String) {
		
	}
	
	func report(messageIds: [String], completion: @escaping (Result<DeliveryReportResponse>) -> Void) {
		completion(Result.Success(DeliveryReportResponse.init()))
	}
}

class NotificationExtensionMessageStorageStub: AppGroupMessageStorage {
	var inMemStorage = [String: Any]()
	let applicationCode: String
	required init?(applicationCode: String, appGroupId: String) {
		self.applicationCode = applicationCode
	}
	
	func save(message: MTMessage) {
		var msgs = (inMemStorage[applicationCode] as? [MTMessage]) ?? [MTMessage]()
		msgs.append(message)
		inMemStorage[applicationCode] = msgs
	}
	
	func retrieveMessages() -> [MTMessage] {
		return (inMemStorage[applicationCode] as? [MTMessage]) ?? [MTMessage]()
	}
	
	func cleanupMessages() {
		inMemStorage[applicationCode] = nil
	}
}
