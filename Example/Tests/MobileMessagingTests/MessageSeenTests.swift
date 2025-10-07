// 
//  Example/Tests/MobileMessagingTests/MessageSeenTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
import CoreData
@testable import MobileMessaging

class MessageSeenTests: MMTestCase {
	
	func testSendSeenStatusUpdate() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var seenRequestCompleted = expectation(description: "seen request completed")
		let messageId = "m1"
		
		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": messageId]) { _ in
            self.mobileMessagingInstance.setSeen(userInitiated: true, messageIds: [messageId], immediately: false, completion: {
				 seenRequestCompleted?.fulfill()
			})
		}

		self.waitForExpectations(timeout: 60) { _ in
			let ctx = self.storage.mainThreadManagedObjectContext!
			ctx.performAndWait {
				if let messages = MessageManagedObject.MM_findAllInContext(ctx) {
					let m1 = messages.filter({$0.messageId == "m1"}).first
					XCTAssertEqual(m1!.seenStatus, MMSeenStatus.SeenNotSent, "m1 must be seen and synced")
				} else {
					XCTFail("There should be some messages in database")
				}
			}
		}
	}
	
    func testSendEmpty() {
        MMTestCase.startWithCorrectApplicationCode()
        
        weak var expectation = self.expectation(description: "expectation")
		
		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": "m1"]) { _ in
            self.mobileMessagingInstance.setSeen(userInitiated: true, messageIds: [], immediately: false, completion: {
				expectation?.fulfill()
			})
		}
		
		self.waitForExpectations(timeout: 60) { _ in
			let ctx = self.storage.mainThreadManagedObjectContext!
			ctx.reset()
			ctx.performAndWait {
				if let messages = MessageManagedObject.MM_findAllInContext(ctx) {
					let m1 = messages.filter({$0.messageId == "m1"}).first!
					XCTAssertEqual(m1.seenStatus, MMSeenStatus.NotSeen, "m1 must be seen and synced")
					XCTAssertEqual(m1.seenDate, nil, "seen date must be nil")
				} else {
					XCTFail("There should be some messages in database")
				}
			}
		}
    }
	
	func testSendSeenAgain() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "expectation")
		let messageReceivingGroup = DispatchGroup()
		
		for mId in ["m1", "m2", "m3"] {
			messageReceivingGroup.enter()
            mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": mId, "customPayload": ["tag1", "tag2"]],  completion: { _ in
				messageReceivingGroup.leave()
			})
		}
		
		messageReceivingGroup.notify(queue: DispatchQueue.main) { 
			self.mobileMessagingInstance.setSeen(userInitiated: true, messageIds: ["m1", "m2"], immediately: false, completion: {
				
				var messagesSeenDates = [String: Date?]()
				let ctx = self.storage.mainThreadManagedObjectContext!
				ctx.reset()
				ctx.performAndWait {
					if let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", ["m1", "m2"]), context: ctx) , messages.count > 0 {
						
						for m in messages {
							XCTAssertEqual(m.seenStatus, MMSeenStatus.SeenNotSent)
							messagesSeenDates[m.messageId] = m.seenDate
						}
						
						if let m3 = messages.filter({ $0.messageId == "m3" }).first {
							XCTAssertEqual(m3.seenStatus, MMSeenStatus.NotSeen)
						}
					} else {
						XCTFail("There should be some messages in database")
					}
				}
				
                self.mobileMessagingInstance.setSeen(userInitiated: true, messageIds: ["m1", "m2", "m3"], immediately: false, completion: {

					let ctx = self.storage.mainThreadManagedObjectContext!
					ctx.reset()
					ctx.performAndWait {
						if let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", ["m1", "m2"]), context: ctx) , messages.count > 0 {
							
							for m in messages {
								XCTAssertEqual(m.seenStatus, MMSeenStatus.SeenNotSent)
								XCTAssertEqual(m.seenDate, messagesSeenDates[m.messageId]!)
							}

						} else {
							XCTFail("There should be some messages in database")
						}
						expectation?.fulfill()
					}
				})
			})
		}

        self.waitForExpectations(timeout: 60, handler: nil)
    }
}
