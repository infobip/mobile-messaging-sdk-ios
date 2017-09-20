//
//  MOMessageSendingTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 21.07.16.
//

import XCTest
@testable import MobileMessaging

class MOMessageSendingTests: MMTestCase {

	private func assertMoMessagesCount(_ cnt: Int, completion: (() -> Void)? = nil) {
		let ctx = self.storage.mainThreadManagedObjectContext!
		ctx.reset()
		
		let work = {
			if let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageTypeValue == \(MMMessageType.MO.rawValue)"), context: ctx) {
				XCTAssertEqual(messages.count, cnt, "there should be \(cnt) messages")
			}
			completion?()
		}
		
		if Thread.isMainThread {
			work()
		} else {
			ctx.perform(work)
		}
	}
	
	func testInteractionMOAndRetries() {
		weak var expectation = self.expectation(description: "Sending finished")
		//Precondiotions
		let messageSyncQ = mobileMessagingInstance.remoteApiManager.messageSyncQueue
		mobileMessagingInstance.remoteApiManager.messageSyncQueue = MMRemoteAPIAlwaysFailing(mmContext: mobileMessagingInstance)
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let moMessage1 = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey" : "customValue1" as CustomPayloadSupportedTypes], composedDate: Date(), bulkId: "bulkId1", initialMessageId: "initialMessageId1")
		let moMessage2 = MOMessage(messageId: "m2", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message2", customPayload: ["customKey" : "customValue2" as CustomPayloadSupportedTypes], composedDate: Date(), bulkId: "bulkId2", initialMessageId: "initialMessageId2")
		
		self.assertMoMessagesCount(0)
		
		// we try first time and fail due to mocked MMRemoteAPIAlwaysFailing
		self.mobileMessagingInstance.sendMessagesSDKInitiated([moMessage1, moMessage2]) { (messages, error) in
			XCTAssertNotNil(error)
			
			self.assertMoMessagesCount(2) {
			
				self.mobileMessagingInstance.remoteApiManager.messageSyncQueue = messageSyncQ
				
				// we re-try next time and succeed
				self.mobileMessagingInstance.retryMoMessageSending() { (messages, error) in
					XCTAssertNotNil(messages)
					XCTAssertEqual(messages?.count, 2)
					
					XCTAssertEqual(messages?.first?.messageId, "m1")
					XCTAssertEqual(messages?.first?.text, "message1")
					XCTAssertEqual(messages?.first?.destination, MMTestConstants.kTestCorrectApplicationCode)
					XCTAssertEqual(messages?.first?.customPayload as! [String: String], ["customKey" : "customValue1"])
					XCTAssertEqual(messages?.first?.sentStatus, MOMessageSentStatus.SentSuccessfully)
					
					XCTAssertEqual(messages?.last?.messageId, "m2")
					XCTAssertEqual(messages?.last?.text, "message2")
					XCTAssertEqual(messages?.last?.destination, MMTestConstants.kTestCorrectApplicationCode)
					XCTAssertEqual(messages?.last?.customPayload as! [String: String], ["customKey" : "customValue2"])
					XCTAssertEqual(messages?.last?.sentStatus, MOMessageSentStatus.SentWithFailure)
					
					XCTAssertNil(error)
					
					// we re-try again next time just to make sure it works fine
					self.mobileMessagingInstance.retryMoMessageSending() { (messages, error) in
						XCTAssertNil(messages)
						XCTAssertNil(error)
						self.assertMoMessagesCount(0) {
							expectation?.fulfill()
						}
					}
				}
			}
		}
		
		waitForExpectations(timeout: 20, handler: { _ in
			
		})
	}
	
	func testMOMessageConstructors() {
		let mo1 = MOMessage(destination: "destination", text: "text", customPayload: ["meal": "pizza" as NSString], composedDate: Date(), bulkId: "bulkId1", initialMessageId: "initialMessageId1")
		let dict1 = mo1.dictRepresentation
		
		let mo2 = MOMessage(payload: dict1, composedDate: Date())
		XCTAssertNotNil(mo2)
		let dict2 = mo2?.dictRepresentation
		
		let d1 = dict1 as NSDictionary
		let d2 = dict2! as NSDictionary
		XCTAssertTrue(d1.isEqual(d2))
	}
	
    func testSendMOMessageSuccessfully() {
		
		weak var expectation = self.expectation(description: "Sending finished")
		
		//Precondiotions
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let moMessage1 = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey" : "customValue1" as CustomPayloadSupportedTypes], composedDate: Date(), bulkId: "bulkId1", initialMessageId: "initialMessageId1")
		let moMessage2 = MOMessage(messageId: "m2", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message2", customPayload: ["customKey" : "customValue2" as CustomPayloadSupportedTypes], composedDate: Date(), bulkId: "bulkId2", initialMessageId: "initialMessageId2")

		self.assertMoMessagesCount(0)
		
		MobileMessaging.sendMessages([moMessage1, moMessage2]) { (messages, error) in
			XCTAssertEqual(messages?.count, 2)
			
			XCTAssertEqual(messages?.first?.messageId, "m1")
			XCTAssertEqual(messages?.first?.text, "message1")
			XCTAssertEqual(messages?.first?.destination, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertEqual(messages?.first?.customPayload as! [String: String], ["customKey" : "customValue1"])
			XCTAssertEqual(messages?.first?.sentStatus, MOMessageSentStatus.SentSuccessfully)
			
			XCTAssertEqual(messages?.last?.messageId, "m2")
			XCTAssertEqual(messages?.last?.text, "message2")
			XCTAssertEqual(messages?.last?.destination, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertEqual(messages?.last?.customPayload as! [String: String], ["customKey" : "customValue2"])
			XCTAssertEqual(messages?.last?.sentStatus, MOMessageSentStatus.SentWithFailure)
			
			expectation?.fulfill()
		}
		
		waitForExpectations(timeout: 20, handler: { _ in
			self.assertMoMessagesCount(0)
		})
    }
	
	func testUserInitiatedMO() {
		weak var expectation = self.expectation(description: "Sending finished")
		//Precondiotions
		mobileMessagingInstance.remoteApiManager.messageSyncQueue = MMRemoteAPIAlwaysFailing(mmContext: mobileMessagingInstance)
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let moMessage1 = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey" : "customValue1" as CustomPayloadSupportedTypes], composedDate: Date(), bulkId: "bulkId1", initialMessageId: "initialMessageId1")
		let moMessage2 = MOMessage(messageId: "m2", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message2", customPayload: ["customKey" : "customValue2" as CustomPayloadSupportedTypes], composedDate: Date(), bulkId: "bulkId2", initialMessageId: "initialMessageId2")
		
		self.assertMoMessagesCount(0)
		
		// we try first time and fail due to mocked MMRemoteAPIAlwaysFailing
		MobileMessaging.sendMessages([moMessage1, moMessage2]) { (messages, error) in
			XCTAssertNotNil(error)
			
			// for users API there must be no persisting for MO
			
			expectation?.fulfill()
		}
		
		waitForExpectations(timeout: 20, handler: { _ in
			self.assertMoMessagesCount(0)
		})
	}
}
