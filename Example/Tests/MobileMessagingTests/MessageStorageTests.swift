//
//  MessageStorageTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 15/09/16.
//

import XCTest
import UserNotifications
@testable import MobileMessaging

class MessageStorageTests: MMTestCase {
	
	func apnsChatMessagePayload(_ messageId: String) -> [AnyHashable: Any] {
		return [
			"messageId": messageId,
			"aps": ["alert": ["title": "msg_title", "body": "msg_body"], "badge": 6, "sound": "default"],
			"internalData": ["sendDateTime": testEnvironmentTimestampMillisSince1970, "internalKey": "internalValue", "messageType": "chat"],
			"customPayload": ["customKey": "customValue"]
		]
	}

	func testThatMessagesFromAPNSAndFromNotificationExtensionStorageDontRepeatAfterEviction() {
		// 1 receive message
		// 2 evict
		// 3 fetch the same message from extension
		// 4 assert no duplicates in message storage
		MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withDefaultMessageStorage().doStart()

		mobileMessagingInstance.sharedNotificationExtensionStorage = NotificationExtensionStorageStub()

		weak var findAllMessagesIdsExp = expectation(description: "Check finished")
		let expectedMessagesCount = 1

		weak var findAllMessagesExp2 = expectation(description: "Check finished")

		self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: false, userInfo: apnsNormalMessagePayload("m2"), completion: { _ in
            self.mobileMessagingInstance.messageHandler.evictOldMessages(userInitiated: false) {
                self.mobileMessagingInstance.messageHandler.syncMessagesWithOuterLocalSources(userInitiated: false) {
					DispatchQueue.main.async {
						self.defaultMessageStorage?.findAllMessageIds(completion: { ids in
							XCTAssertEqual(ids.count, expectedMessagesCount)
							findAllMessagesIdsExp?.fulfill()
						})
						self.defaultMessageStorage?.findAllMessages { messages in
							XCTAssertEqual(messages?.count, expectedMessagesCount)
							findAllMessagesExp2?.fulfill()
						}
					}
				}
			}
		})

		self.waitForExpectations(timeout: 60, handler: nil)
	}

	func testThatMessagesFromAPNSAndFromNotificationExtensionStorageDontRepeat() {
		// 1 receive message
		// 2 fetch the same message from extension
		// 3 assert no duplicates in message storage
		MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withDefaultMessageStorage().doStart()

		mobileMessagingInstance.sharedNotificationExtensionStorage = NotificationExtensionStorageStub()

		weak var findAllMessagesIdsExp = expectation(description: "Check finished")
		let expectedMessagesCount = 1

		weak var findAllMessagesExp2 = expectation(description: "Check finished")

		self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: false, userInfo: apnsNormalMessagePayload("m2"), completion: { _ in
            self.mobileMessagingInstance.messageHandler.syncMessagesWithOuterLocalSources(userInitiated: false) {
				DispatchQueue.main.async {
					self.defaultMessageStorage?.findAllMessageIds(completion: { ids in
						XCTAssertEqual(ids.count, expectedMessagesCount)
						findAllMessagesIdsExp?.fulfill()
					})
					self.defaultMessageStorage?.findAllMessages { messages in
						XCTAssertEqual(messages?.count, expectedMessagesCount)
						findAllMessagesExp2?.fulfill()
					}
				}
			}
		})

		self.waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testThatChatMessagesDontGetToMessageStorage() {
		let messageStorageStub = MessageStorageStub()
		MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withMessageStorage(messageStorageStub).withInAppChat().doStart()
		
		XCTAssertEqual(messageStorageStub.mtMessages.count, 0)
		
		let expectedMessagesCount = 5
		weak var expectation = self.expectation(description: "Check finished")
		var iterationCounter: Int = 0
		
		self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: apnsChatMessagePayload("chatmessageid"), completion: { _ in
			
			sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
				self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: userInfo, completion: { _ in
					DispatchQueue.main.async {
						iterationCounter += 1
						if iterationCounter == expectedMessagesCount {
							expectation?.fulfill()
						}
					}
				})
			}
		})
		
		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertEqual(messageStorageStub.mtMessages.count, expectedMessagesCount)
			XCTAssertEqual(messageStorageStub.moMessages.count, 0)
		})
	}

	func testThatOldMessagesDontGetToMessageStorage() {
		let messageStorageStub = MessageStorageStub()
		MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withMessageStorage(messageStorageStub).withInAppChat().doStart()

		XCTAssertEqual(messageStorageStub.mtMessages.count, 0)

		let expectedMessagesCount = 5
		weak var expectation = self.expectation(description: "Check finished")
		var iterationCounter: Int = 0

		timeTravel(to: Date()) {
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: apnsChatMessagePayload("chatmessageid"), completion: { _ in

				sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
					self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: userInfo, completion: { _ in
						DispatchQueue.main.async {
							iterationCounter += 1
							if iterationCounter == expectedMessagesCount {
								expectation?.fulfill()
							}
						}
					})
				}
			})
		}

		self.waitForExpectations(timeout: 60, handler: { _ in
			XCTAssertEqual(messageStorageStub.mtMessages.count, 0)
			XCTAssertEqual(messageStorageStub.moMessages.count, 0)
		})
	}
	
	private var defaultMessageStorage: MMDefaultMessageStorage? {
		return self.mobileMessagingInstance.messageStorages["messages"]?.adapteeStorage as? MMDefaultMessageStorage
	}
	
	func testMODuplication() {
		weak var expectation1 = expectation(description: "Sending 1 finished")
		weak var expectation2 = expectation(description: "Sending 2 finished")
        
		let messageStorageStub = MessageStorageStub()
		XCTAssertEqual(messageStorageStub.moMessages.count, 0)
		MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withMessageStorage(messageStorageStub).doStart()
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		do {
			let moMessage = MM_MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey": "customValue1" as NSString], composedDate: Date(), bulkId: nil, initialMessageId: nil, sentStatus: .Undefined, deliveryMethod: .generatedLocally)
			MobileMessaging.sendMessages([moMessage]) { (messages, error) in
				expectation1?.fulfill()
			}
		}
		
		do {
			let moMessage = MM_MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey": "customValue1" as NSString], composedDate: Date(), bulkId: nil, initialMessageId: nil, sentStatus: .Undefined, deliveryMethod: .generatedLocally)
			MobileMessaging.sendMessages([moMessage]) { (messages, error) in
				expectation2?.fulfill()
			}
		}
		
		waitForExpectations(timeout: 60, handler: { error in
			XCTAssertEqual(messageStorageStub.moMessages.count, 1)
		})
	}
	
	func testMOHooks() {
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
		
		MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withMessageStorage(messageStorageStub).doStart()

		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let moMessage1 = MM_MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey": "customValue1" as NSString], composedDate: Date(), bulkId: "bulkId1", initialMessageId: "initialMessageId1", sentStatus: .Undefined, deliveryMethod: .generatedLocally)
		let moMessage2 = MM_MOMessage(messageId: "m2", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message2", customPayload: ["customKey": "customValue2" as NSString], composedDate: Date(), bulkId: "bulkId2", initialMessageId: "initialMessageId2", sentStatus: .Undefined, deliveryMethod: .generatedLocally)
		
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
		MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withDefaultMessageStorage().doStart()
		
		weak var findAllMessagesExp1 = expectation(description: "Check finished")
		weak var findAllMessagesIdsExp = expectation(description: "Check finished")
		self.defaultMessageStorage?.findAllMessages { results in
			XCTAssertEqual(results?.count, 0)
			findAllMessagesExp1?.fulfill()
		}
		
		let expectedMessagesCount = 5
		weak var findAllMessagesExp2 = expectation(description: "Check finished")
		
		var iterationCounter: Int = 0
        
		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: userInfo, completion: { _ in
				
				DispatchQueue.main.async {
					iterationCounter += 1
				
					if iterationCounter == expectedMessagesCount {
						self.defaultMessageStorage?.findAllMessageIds(completion: { (mids) in
							XCTAssertEqual(mids.count, expectedMessagesCount)
							findAllMessagesIdsExp?.fulfill()
						})
						self.defaultMessageStorage?.findAllMessages { results in
							XCTAssertEqual(results?.count, expectedMessagesCount)
							findAllMessagesExp2?.fulfill()
						}
					}
				}
			})
		}

		self.waitForExpectations(timeout: 60, handler: nil)
    }

	func testThatSeenStatusUpdatesPersisted() {
		MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withDefaultMessageStorage().doStart()

		weak var findAllMessagesIdsExp = expectation(description: "Check finished")
		weak var setSeenExpectation = expectation(description: "Check finished")
		weak var checkExp = expectation(description: "Check finished")
		let expectedMessagesCount = 5
		var iterationCounter: Int = 0
		var notSeenCounter = -1
		var totalCounter = -1

		MobileMessaging.defaultMessageStorage?.messagesCountersUpdateHandler = {(total:Int, notSeen: Int)in
			notSeenCounter = notSeen
			totalCounter = total
		}

		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in

			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: userInfo, completion: { _ in
				DispatchQueue.main.async {
					iterationCounter += 1
					if iterationCounter == expectedMessagesCount {
						MobileMessaging.defaultMessageStorage?.findNonSeenMessageIds { (messageIds) in
							XCTAssertEqual(messageIds.count, expectedMessagesCount)
							MobileMessaging.setSeen(messageIds: messageIds, completion: {
								setSeenExpectation?.fulfill()

								// assertion 1
								MobileMessaging.defaultMessageStorage?.findNonSeenMessageIds { (messageIds) in
									XCTAssertEqual(messageIds.count, 0)
									MobileMessaging.defaultMessageStorage?.findMessages(withIds: messageIds, completion: { (messages: [MMBaseMessage]?) in
										XCTAssertNil(messages)
										findAllMessagesIdsExp?.fulfill()
									})
								}

								// assertion 2
								let q = MMQuery()
								q.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
								MobileMessaging.defaultMessageStorage?.findMessages(withQuery: q, completion: { (messages: [MMBaseMessage]?) in
									XCTAssertEqual(messages!.count, expectedMessagesCount)
									checkExp?.fulfill()
								})
							})
						}
					}
				}
			})
		}

		self.waitForExpectations(timeout: 60, handler: { error in
			XCTAssertEqual(notSeenCounter, 0)
			XCTAssertEqual(totalCounter, expectedMessagesCount)
		})
	}
	
	func testCustomPersistingAndFetching() {
		let messageStorageStub = MessageStorageStub()
		
		MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withMessageStorage(messageStorageStub).doStart()
		
		XCTAssertEqual(messageStorageStub.mtMessages.count, 0)
		
		let expectedMessagesCount = 5
		weak var expectation = self.expectation(description: "Check finished")
		var iterationCounter: Int = 0
		sendPushes(apnsNormalMessagePayload, count: expectedMessagesCount) { userInfo in
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: userInfo, completion: { _ in
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
			XCTAssertEqual(MMTestCase.allStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), expectedMessagesCount, "Messages must be persisted properly")
		})
	}
	
	
	func testQuery() {
		MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)?.withDefaultMessageStorage().doStart()
		
		let messageReceivingGroup = DispatchGroup()
		weak var expectation = self.expectation(description: "Check finished")
		
		do {
			let payload = apnsNormalMessagePayload("001")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
				messageReceivingGroup.leave()
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("002")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
				messageReceivingGroup.leave()
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("003")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
				messageReceivingGroup.leave()
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("004")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
				messageReceivingGroup.leave()
			})
		}
		
		do {
			let payload = apnsNormalMessagePayload("005")
			messageReceivingGroup.enter()
			self.mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: payload,  completion: { _ in
				messageReceivingGroup.leave()
			})
		}
		
		messageReceivingGroup.notify(queue: DispatchQueue.main) { 
			let q = MMQuery()
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
		MobileMessagingNotificationServiceExtension.sharedInstance?.deliveryReporter = SuccessfullDeliveryReporterStub()
		MobileMessagingNotificationServiceExtension.sharedInstance?.sharedNotificationExtensionStorage = notificationExtensionStorageStub
		MobileMessagingNotificationServiceExtension.didReceive(request, withContentHandler: contentHandler)
		
		XCTAssertEqual(notificationExtensionStorageStub.retrieveMessages().count, 1)
		let firstMessage = notificationExtensionStorageStub.retrieveMessages().first
		XCTAssertNotNil(firstMessage!.deliveryReportedDate)
		XCTAssertTrue(firstMessage!.isDeliveryReportSent)
		
		// starting the SDK
		let messageStorageStub = MessageStorageStub()
		XCTAssertEqual(messageStorageStub.mtMessages.count, 0)
		
		let mm = MMTestCase.stubbedMMInstanceWithApplicationCode(MMTestConstants.kTestCorrectApplicationCode)!.withMessageStorage(messageStorageStub)
        mm.sharedNotificationExtensionStorage = notificationExtensionStorageStub
        mm.doStart()
		
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
	func report(applicationCode: String, messageIds: [String], completion: @escaping (NSError?) -> Void) {
		completion(nil)
	}
}

class NotificationExtensionMessageStorageStub: AppGroupMessageStorage {
	var inMemStorage = [String: Any]()
	let applicationCode: String
	required init?(applicationCode: String, appGroupId: String) {
		self.applicationCode = applicationCode
	}
	
	func save(message: MM_MTMessage) {
		var msgs = (inMemStorage[applicationCode] as? [MM_MTMessage]) ?? [MM_MTMessage]()
		msgs.append(message)
		inMemStorage[applicationCode] = msgs
	}
	
	func retrieveMessages() -> [MM_MTMessage] {
		return (inMemStorage[applicationCode] as? [MM_MTMessage]) ?? [MM_MTMessage]()
	}
	
	func cleanupMessages() {
		inMemStorage[applicationCode] = nil
	}
}
