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
		
		let seenRequestCompleted = expectationWithDescription("seen request completed")
		let messageId = "m1"
		
		mobileMessagingInstance.didReceiveRemoteNotification(["messageId": messageId], newMessageReceivedCallback: nil) { err in
			self.mobileMessagingInstance.setSeen([messageId], completion: { result in
				seenRequestCompleted.fulfill()
			})
		}

		self.waitForExpectationsWithTimeout(100) { err in
			let ctx = self.storage.mainThreadManagedObjectContext!
			ctx.performBlockAndWait {
				if let messages = MessageManagedObject.MM_findAllInContext(ctx) as? [MessageManagedObject] {
					let m1 = messages.filter({$0.messageId == "m1"}).first
					XCTAssertEqual(m1!.seenStatus, MMSeenStatus.SeenSent, "m1 must be seen and synced")
				} else {
					XCTFail("There should be some messages in database")
				}
			}
		}
	}
	
    func testSendEmpty() {
        let expectation = expectationWithDescription("expectation")
		
		mobileMessagingInstance.didReceiveRemoteNotification(["messageId": "m1"], newMessageReceivedCallback: nil) { err in
			self.mobileMessagingInstance.setSeen([], completion: { result in
				expectation.fulfill()
			})
		}
		
		self.waitForExpectationsWithTimeout(100) { err in
			let ctx = self.storage.mainThreadManagedObjectContext!
			ctx.performBlockAndWait {
				if let messages = MessageManagedObject.MM_findAllInContext(ctx) as? [MessageManagedObject] {
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
		let expectation = expectationWithDescription("expectation")
		let messageReceivingGroup = dispatch_group_create()
		
		for mId in ["m1", "m2", "m3"] {
			dispatch_group_enter(messageReceivingGroup)
			mobileMessagingInstance.didReceiveRemoteNotification(["messageId": mId], newMessageReceivedCallback: nil, completion: { (err) in
				dispatch_group_leave(messageReceivingGroup)
			})
		}
		
		dispatch_group_notify(messageReceivingGroup, dispatch_get_main_queue()) { 
			self.mobileMessagingInstance.setSeen(["m1", "m2"], completion: { result in
				
				var messagesSeenDates = [String: NSDate?]()
				let ctx = self.storage.mainThreadManagedObjectContext!
				ctx.reset()
				ctx.performBlockAndWait {
					if let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", ["m1", "m2"]), inContext: ctx) as? [MessageManagedObject] where messages.count > 0 {
						
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
					ctx.performBlockAndWait {
						if let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", ["m1", "m2"]), inContext: ctx) as? [MessageManagedObject] where messages.count > 0 {
							
							for m in messages {
								XCTAssertEqual(m.seenStatus, MMSeenStatus.SeenSent)
								XCTAssertEqual(m.seenDate, messagesSeenDates[m.messageId]!)
							}

						} else {
							XCTFail("There should be some messages in database")
						}
						expectation.fulfill()
					}
				})
			})
		}

        self.waitForExpectationsWithTimeout(100, handler: nil)
    }
}
