//
//  SyncMessagesTest.swift
//  MobileMessaging
//
//  Created by okoroleva on 21.03.16.
//

import XCTest

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
		cleanUpAndStop()
		startWithApplicationCode(SyncTestAppIds.kCorrectIdNothingToSynchronize)
		
		let expectation = self.expectation(description: "Sync finished")
        XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 0, "There must be not any stored message")
                
        let messageHandler = mobileMessagingInstance.messageHandler
		
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		messageHandler?.syncWithServer { error in
			
			XCTAssertNil(error)
			XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 0, "There must be not any stored message")
			expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
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
		let prepconditionExpectation = expectation(description: "Initial message base set up")
		let seenExpectation = expectation(description: "Seen request finished")
		let syncExpectation = expectation(description: "Sync finished")
		let newMsgExpectation = expectation(description: "New message received")

		cleanUpAndStop()
		startWithApplicationCode(SyncTestAppIds.kCorrectIdMergeSynchronization)
		
		//Precondiotions
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": "m2"], newMessageReceivedCallback: nil, completion: { error in
			prepconditionExpectation.fulfill()
		})
		
		//Actions
		mobileMessagingInstance.setSeen(["m2"], completion: { result in
			seenExpectation.fulfill()
		})
		
		mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": "m1"], newMessageReceivedCallback: nil, completion: { error in
			newMsgExpectation.fulfill()
		})

		mobileMessagingInstance.messageHandler?.syncWithServer({ error in
			syncExpectation.fulfill()
		})
		
		//Expectations
		waitForExpectations(timeout: 50) { error in
			let ctx = self.storage.mainThreadManagedObjectContext!
			ctx.reset()
			ctx.performAndWait {
				if let messages = MessageManagedObject.MM_findAllInContext(ctx) {
					let m1 = messages.filter({$0.messageId == "m1"}).first
					let m2 = messages.filter({$0.messageId == "m2"}).first
					XCTAssertEqual(m2?.seenStatus, MMSeenStatus.SeenSent, "m2 must be seen and synced")
					XCTAssertEqual(m2?.reportSent, NSNumber(value: true), "m2 delivery report must be delivered")
					XCTAssertEqual(m1?.seenStatus, MMSeenStatus.NotSeen, "m1 must be not seen")
					XCTAssertEqual(m1?.reportSent, NSNumber(value: true), "m1 delivery report must be delivered")
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
		let newMsgExpectation1 = expectation(description: "New message m1 received")
		let newMsgExpectation2 = expectation(description: "New message m2 received")
		let syncExpectation = expectation(description: "Sync finished")
		
		var newMsgCounter = 0
		expectation(forNotification: MMNotificationMessageReceived, object: nil) { n -> Bool in
			if	let userInfo = n.userInfo,
				let messageDict = userInfo[MMNotificationKeyMessagePayload] as? [String : Any],
				let isPushFlag = n.userInfo?[MMNotificationKeyMessageIsPush] as? Bool,
				let messageId = messageDict.mm_messageId
			{
				if ["m1", "m2"].contains(messageId) {
					XCTAssertTrue(isPushFlag)
				}
				if ["m3", "m4"].contains(messageId) {
					XCTAssertFalse(isPushFlag)
				}
			} else {
				XCTFail()
			}

			newMsgCounter += 1
			return newMsgCounter == 4 // we must emit 4 unique kMessageReceived notifications
		}
		
		cleanUpAndStop()
		startWithApplicationCode(SyncTestAppIds.kCorrectIdMergeSynchronization)
		
        let messagesCtx = storage.mainThreadManagedObjectContext!
		
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": "m1"], newMessageReceivedCallback: nil, completion: { error in
			newMsgExpectation1.fulfill()
		})
	
		mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": "m2"], newMessageReceivedCallback: nil, completion: { error in
			newMsgExpectation2.fulfill()
		})
		
        let messageHandler = mobileMessagingInstance.messageHandler
		messageHandler?.syncWithServer { error in
			syncExpectation.fulfill()
		}
		
		waitForExpectations(timeout: 50) { error in
			
			messagesCtx.performAndWait {
				if let messagesAfterSync = MessageManagedObject.MM_findAllInContext(messagesCtx) {
					let mIdsToCheck = Set(messagesAfterSync.map{$0.messageId})
					let mIds = Set(["m1", "m2", "m3", "m4"])
					let diff = mIdsToCheck.symmetricDifference(mIds)
					XCTAssertTrue(diff.isEmpty, "Not Expected mIds in DB: \(diff)")
				}
			}
		}
    }
	
	func testThatAlertIsShown() {
		let newMsgExpectation1 = expectationWithDescription("New message m1 received")
		let newMsgExpectation2 = expectationWithDescription("New message m2 received")
		let syncExpectation = expectationWithDescription("Sync finished")
		
		
		
		cleanUpAndStop()
		startWithApplicationCode(SyncTestAppIds.kCorrectIdMergeSynchronization)
		
		var alertShownCounter = 0
		MobileMessaging.messageHandling = MessageHandlingMock(localNotificationShownBlock: {
			alertShownCounter += 1
		})
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		mobileMessagingInstance.didReceiveRemoteNotification(["aps":["key":"value"], "messageId": "m1"], newMessageReceivedCallback: nil, completion: { error in
			newMsgExpectation1.fulfill()
		})
		
		mobileMessagingInstance.didReceiveRemoteNotification(["aps":["key":"value"], "messageId": "m2"], newMessageReceivedCallback: nil, completion: { error in
			newMsgExpectation2.fulfill()
		})
		
		let messageHandler = mobileMessagingInstance.messageHandler
		messageHandler?.syncWithServer { error in
			syncExpectation.fulfill()
		}
		
		waitForExpectationsWithTimeout(50) { error in
			XCTAssertEqual(alertShownCounter, 2)
		}
	}
}

class MessageHandlingMock : MMDefaultMessageHandling {
	let localNotificationShownBlock: Void -> Void
	init(localNotificationShownBlock: Void -> Void) {
		self.localNotificationShownBlock = localNotificationShownBlock
	}
	override func presentLocalNotificationAlert(with message: MTMessage) {
		self.localNotificationShownBlock()
	}
}
