//
//  SyncMessagesTest.swift
//  MobileMessaging
//
//  Created by okoroleva on 21.03.16.
//

import XCTest
import CocoaLumberjack

@testable import MobileMessaging

struct SyncTestAppIds {
    static let kCorrectIdNothingToSynchronize = "CorrectIdNothingToSynchronize"
    static let kCorrectIdMergeSynchronization = "CorrectIdMergeSynchronization"
}

class FetchMessagesTest: MMTestCase {
    /**Conditions:
    1. Empty DB
    2. synchronization request was sent
    3. empty mIds response received
     
     Expected result:
     nothing changed in DB
    */
    func testNothingToSynchronize() {
		MobileMessaging.stop()
		MobileMessaging.testStartWithApplicationCode(SyncTestAppIds.kCorrectIdNothingToSynchronize)
		
		let expectation = expectationWithDescription("Sync finished")
        XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 0, "There must be not any stored message")
                
        let messageHandler = mobileMessagingInstance.messageHandler
		
		mobileMessagingInstance.currentInstallation?.internalId = MMTestConstants.kTestCorrectInternalID
		
		messageHandler?.syncWithServer { error in
			
			XCTAssertNil(error)
			XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 0, "There must be not any stored message")
			expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(10, handler: nil)
    }
	
	/**
	Preconditions:
	1. m2(new message) is in DB
	Actions:
	1. new message m1 received
	2. sync
	Expectations:
	m2 seen and deivered, m1 delivered
	*/
	func testConcurrency() {
		let prepconditionExpectation = expectationWithDescription("Initial message base set up")
		let seenExpectation = expectationWithDescription("Seen request finished")
		let syncExpectation = expectationWithDescription("Sync finished")
		let newMsgExpectation = expectationWithDescription("New message received")

		MobileMessaging.stop()
		MobileMessaging.testStartWithApplicationCode(SyncTestAppIds.kCorrectIdMergeSynchronization)
		
		//Precondiotions
		mobileMessagingInstance.currentInstallation?.internalId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.didReceiveRemoteNotification(["messageId": "m2"], newMessageReceivedCallback: {}, completion: { error in
			prepconditionExpectation.fulfill()
		})
		
		//Actions
		mobileMessagingInstance.setSeen(["m2"], completion: { result in
			seenExpectation.fulfill()
		})
		
		mobileMessagingInstance.didReceiveRemoteNotification(["messageId": "m1"], newMessageReceivedCallback: {}, completion: { error in
			newMsgExpectation.fulfill()
		})

		mobileMessagingInstance.messageHandler?.syncWithServer({ error in
			syncExpectation.fulfill()
		})
		
		//Expectations
		waitForExpectationsWithTimeout(50) { error in
			let ctx = self.mobileMessagingInstance.messageHandler!.storageContext
			ctx.performBlockAndWait {
				if let messages = MessageManagedObject.MM_findAllInContext(ctx) as? [MessageManagedObject] {
					let m1 = messages.filter({$0.messageId == "m1"}).first
					let m2 = messages.filter({$0.messageId == "m2"}).first
					XCTAssertEqual(m2?.seenStatus, MMSeenStatus.SeenSent, "m2 must be seen and synced")
					XCTAssertEqual(m2?.reportSent, NSNumber(bool: true), "m2 delivery report must be delivered")
					XCTAssertEqual(m1?.seenStatus, MMSeenStatus.NotSeen, "m1 must be not seen")
					XCTAssertEqual(m1?.reportSent, NSNumber(bool: true), "m1 delivery report must be delivered")
				} else {
					XCTFail("There should be some messages in database")
				}
			}
		}
	}

    /** Conditions:
     1. m1(delivery sent), m2(delivery not sent) - are in DB
     2. fetch request was sent
     3. m1, m3, m4 response received
     
     Expected result:
     m1, m2, m3, m4 are in DB
     */
    func testMergeOldMessageIdsWithNew() {
		let newMsgExpectation1 = expectationWithDescription("New message m1 received")
		let newMsgExpectation2 = expectationWithDescription("New message m2 received")
		let syncExpectation = expectationWithDescription("Sync finished")
		var newMsgCounter = 0
		expectationForNotification(MMEventNotifications.kMessageReceived, object: nil) { (n) -> Bool in
			newMsgCounter += 1
			return newMsgCounter == 4 // we must emit 4 unique kMessageReceived notifications
		}
		
		MobileMessaging.stop()
		MobileMessaging.testStartWithApplicationCode(SyncTestAppIds.kCorrectIdMergeSynchronization)
		
        let messagesCtx = storage.mainThreadManagedObjectContext!
		
		mobileMessagingInstance.currentInstallation?.internalId = MMTestConstants.kTestCorrectInternalID
		
		mobileMessagingInstance.didReceiveRemoteNotification(["messageId": "m1"], newMessageReceivedCallback: {}, completion: { error in
			newMsgExpectation1.fulfill()
		})
	
		mobileMessagingInstance.didReceiveRemoteNotification(["messageId": "m2"], newMessageReceivedCallback: {}, completion: { error in
			newMsgExpectation2.fulfill()
		})
		
        let messageHandler = mobileMessagingInstance.messageHandler
		messageHandler?.syncWithServer { error in
			syncExpectation.fulfill()
		}
		
		waitForExpectationsWithTimeout(50) { error in
			
			messagesCtx.performBlockAndWait {
				if let messagesAfterSync = MessageManagedObject.MM_findAllInContext(messagesCtx) as? [MessageManagedObject] {
					let mIdsToCheck = Set(messagesAfterSync.map{$0.messageId})
					let mIds = Set(["m1", "m2", "m3", "m4"])
					let diff = mIdsToCheck.exclusiveOr(mIds)
					XCTAssertTrue(diff.isEmpty, "Not Expected mIds in DB: \(diff)")
				}
			}
		}
    }
}