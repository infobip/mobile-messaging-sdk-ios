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
		
		let seenExpectation = expectationWithDescription("Seen request finished")
		let syncExpectation = expectationWithDescription("Sync finished")
		let newMsgExpectation = expectationWithDescription("New message received")
		
		MobileMessaging.stop()
		MobileMessaging.testStartWithApplicationCode(SyncTestAppIds.kCorrectIdMergeSynchronization)
		
		//Precondiotions
		let messagesCtx = storage.mainThreadManagedObjectContext
		mobileMessagingInstance.currentInstallation?.internalId = MMTestConstants.kTestCorrectInternalID
		messagesCtx?.performBlockAndWait {
			let m2 = MessageManagedObject.MR_createEntityInContext(messagesCtx)
			m2.messageId = "m2"
			m2.reportSent = false
			m2.creationDate = NSDate()
			messagesCtx?.MR_saveToPersistentStoreAndWait()
		}
		
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
			messagesCtx?.performBlockAndWait {
				if let messages = MessageManagedObject.MR_findAllInContext(messagesCtx) as? [MessageManagedObject] {
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
     2. fetch request was sent with parameter ["m2"]
     3. m1, m3, m4 response received
     
     Expected result:
     m1, m2, m3, m4 are in DB
     */
    func testMergeOldMessageIdsWithNew() {
        let expectation = expectationWithDescription("Sync finished")
		
		MobileMessaging.stop()
		MobileMessaging.testStartWithApplicationCode(SyncTestAppIds.kCorrectIdMergeSynchronization)
		
        let messagesCtx = storage.mainThreadManagedObjectContext
		print(messagesCtx?.persistentStoreCoordinator?.persistentStores)
		mobileMessagingInstance.currentInstallation?.internalId = MMTestConstants.kTestCorrectInternalID

		messagesCtx?.performBlockAndWait {
			let m1 = MessageManagedObject.MR_createEntityInContext(messagesCtx)
			m1.messageId = "m1"
			m1.reportSent = true
			m1.creationDate = NSDate()
			
			let m2 = MessageManagedObject.MR_createEntityInContext(messagesCtx)
			m2.messageId = "m2"
			m2.reportSent = false
			m2.creationDate = NSDate()
			
			messagesCtx?.MR_saveToPersistentStoreAndWait()
		}
		
        let messageHandler = mobileMessagingInstance.messageHandler
		messageHandler?.syncWithServer { error in
			expectation.fulfill()
		}
		
		waitForExpectationsWithTimeout(50) { error in
			
			messagesCtx?.performBlockAndWait {
				if let messagesAfterSync = MessageManagedObject.MR_findAllInContext(messagesCtx) as? [MessageManagedObject] {
					let mIdsToCheck = Set(messagesAfterSync.map{$0.messageId})
					let mIds = Set(["m1", "m2", "m3", "m4"])
					let diff = mIdsToCheck.exclusiveOr(mIds)
					XCTAssertTrue(diff.isEmpty, "Not Expected mIds in DB: \(diff)")
				}
			}
		}
    }
}