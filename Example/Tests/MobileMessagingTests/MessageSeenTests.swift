//
//  MessageSeenTests.swift
//  MobileMessaging
//
//  Created by okoroleva on 14.04.16.
//

import XCTest
import CoreData
@testable import MobileMessaging

class MessageSeenTests: MMTestCase {
	
	func testSendSeenStatusUpdate() {
		
		weak var seenRequestCompleted = expectation(description: "seen request completed")
		let messageId = "m1"
		
		mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": messageId]) { _ in
			self.mobileMessagingInstance.setSeen([messageId], completion: { result in
				 seenRequestCompleted?.fulfill()
			})
		}

		self.waitForExpectations(timeout: 60) { _ in
			let ctx = self.storage.mainThreadManagedObjectContext!
			ctx.performAndWait {
				if let messages = MessageManagedObject.MM_findAllInContext(ctx) {
					let m1 = messages.filter({$0.messageId == "m1"}).first
					XCTAssertEqual(m1!.seenStatus, MMSeenStatus.SeenSent, "m1 must be seen and synced")
				} else {
					XCTFail("There should be some messages in database")
				}
			}
		}
	}
	
    func testSendEmpty() {
        weak var expectation = self.expectation(description: "expectation")
		
		mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": "m1"]) { _ in
			self.mobileMessagingInstance.setSeen([], completion: { result in
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
		weak var expectation = self.expectation(description: "expectation")
		let messageReceivingGroup = DispatchGroup()
		
		for mId in ["m1", "m2", "m3"] {
			messageReceivingGroup.enter()
			mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": mId],  completion: { _ in
				messageReceivingGroup.leave()
			})
		}
		
		messageReceivingGroup.notify(queue: DispatchQueue.main) { 
			self.mobileMessagingInstance.setSeen(["m1", "m2"], completion: { result in
				
				var messagesSeenDates = [String: Date?]()
				let ctx = self.storage.mainThreadManagedObjectContext!
				ctx.reset()
				ctx.performAndWait {
					if let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", ["m1", "m2"]), context: ctx) , messages.count > 0 {
						
						for m in messages {
							XCTAssertEqual(m.seenStatus, MMSeenStatus.SeenSent)
							messagesSeenDates[m.messageId] = m.seenDate
						}
						
						if let m3 = messages.filter({ $0.messageId == "m3" }).first {
							XCTAssertEqual(m3.seenStatus, MMSeenStatus.NotSeen)
						}
					} else {
						XCTFail("There should be some messages in database")
					}
				}
				
				self.mobileMessagingInstance.setSeen(["m1", "m2", "m3"], completion: { result in

					let ctx = self.storage.mainThreadManagedObjectContext!
					ctx.reset()
					ctx.performAndWait {
						if let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", ["m1", "m2"]), context: ctx) , messages.count > 0 {
							
							for m in messages {
								XCTAssertEqual(m.seenStatus, MMSeenStatus.SeenSent)
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
