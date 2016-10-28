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
		
		weak var expectation = self.expectation(description: "Sync finished")
        XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 0, "There must be not any stored message")
                
        let messageHandler = mobileMessagingInstance.messageHandler
		
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		messageHandler?.syncWithServer { error in
			
			XCTAssertNil(error)
			XCTAssertEqual(self.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 0, "There must be not any stored message")
			expectation?.fulfill()
        }
        
        waitForExpectations(timeout: 60, handler: nil)
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
		weak var prepconditionExpectation = expectation(description: "Initial message base set up")
		weak var seenExpectation = expectation(description: "Seen request finished")
		weak var syncExpectation = expectation(description: "Sync finished")
		weak var newMsgExpectation = expectation(description: "New message received")

		cleanUpAndStop()
		startWithApplicationCode(SyncTestAppIds.kCorrectIdMergeSynchronization)
		
		//Precondiotions
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": "m2"], newMessageReceivedCallback: nil, completion: { error in
			prepconditionExpectation?.fulfill()
		})
		
		//Actions
		mobileMessagingInstance.setSeen(["m2"], completion: { result in
			seenExpectation?.fulfill()
		})
		
		mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": "m1"], newMessageReceivedCallback: nil, completion: { error in
			newMsgExpectation?.fulfill()
		})

		mobileMessagingInstance.messageHandler?.syncWithServer({ error in
			syncExpectation?.fulfill()
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
					XCTAssertEqual(m2?.reportSent, true, "m2 delivery report must be delivered")
					XCTAssertEqual(m1?.seenStatus, MMSeenStatus.NotSeen, "m1 must be not seen")
					XCTAssertEqual(m1?.reportSent, true, "m1 delivery report must be delivered")
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
	/*
    func testMergeOldMessageIdsWithNew() {
		weak var newMsgExpectation1 = expectation(description: "New message m1 received")
		weak var newMsgExpectation2 = expectation(description: "New message m2 received")
		weak var syncExpectation = expectation(description: "Sync finished")
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
		
		
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": "m1"], newMessageReceivedCallback: nil, completion: { error in
			newMsgExpectation1?.fulfill()
		})
	
		mobileMessagingInstance.didReceiveRemoteNotification(["aps": ["key":"value"], "messageId": "m2"], newMessageReceivedCallback: nil, completion: { error in
			newMsgExpectation2?.fulfill()
		})
		
        let messageHandler = mobileMessagingInstance.messageHandler
		messageHandler?.syncWithServer { error in
			syncExpectation?.fulfill()
		}
		
		waitForExpectations(timeout: 50) { error in
			let messagesCtx = self.storage.mainThreadManagedObjectContext!
			messagesCtx.reset()
			messagesCtx.performAndWait {
				if let messagesAfterSync = MessageManagedObject.MM_findAllInContext(messagesCtx) {
					print(messagesAfterSync)
					let mIdsToCheck = Set(messagesAfterSync.map{$0.messageId})
					print(mIdsToCheck)
					let mIds = Set(["m1", "m2", "m3", "m4"])
					let diff = mIdsToCheck.symmetricDifference(mIds)
					print(diff)
					XCTAssertTrue(diff.isEmpty, "Not Expected mIds in DB: \(diff)")
				}
			}
		}
    }
*/
	/*
	func testThatAlertIsShown() {
		weak var newMsgExpectation1 = self.expectation(description: "New message m1 received - alert")
		weak var newMsgExpectation2 = self.expectation(description: "New message m2 received - alert")
		weak var syncExpectation = self.expectation(description: "Sync finished - alert")
		weak var countReached = self.expectation(description: "countReached")
		
		cleanUpAndStop()
		startWithApplicationCode(SyncTestAppIds.kCorrectIdMergeSynchronization)
		
		var alertShownCounter = 0
		MobileMessaging.messageHandling = MessageHandlingMock(localNotificationShownBlock: {
			DispatchQueue.main.async {
				alertShownCounter += 1
				print("alertShownCounter \(alertShownCounter)")
				if (alertShownCounter == 2) {
					print("countReached?.fulfill()")
					countReached?.fulfill()
				}
			}
		})
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		mobileMessagingInstance.didReceiveRemoteNotification(["aps":["key":"value"], "messageId": "m1"], newMessageReceivedCallback: nil, completion: { error in
			print("newMsgExpectation1?.fulfill()")
			newMsgExpectation1?.fulfill()
		})
		
		mobileMessagingInstance.didReceiveRemoteNotification(["aps":["key":"value"], "messageId": "m2"], newMessageReceivedCallback: nil, completion: { error in
			print("newMsgExpectation2?.fulfill()")
			newMsgExpectation2?.fulfill()
		})
		
		let messageHandler = mobileMessagingInstance.messageHandler
		messageHandler?.syncWithServer { error in
			print("syncExpectation?.fulfill()")
			syncExpectation?.fulfill()
		}
		
		waitForExpectations(timeout: 50) { error in
			XCTAssertEqual(alertShownCounter, 2)
		}
	}*/
}

class MessageHandlingMock : MMDefaultMessageHandling {
	let localNotificationShownBlock: (Void) -> Void
	init(localNotificationShownBlock: @escaping (Void) -> Void) {
		self.localNotificationShownBlock = localNotificationShownBlock
	}
	override func presentLocalNotificationAlert(with message: MTMessage) {
		self.localNotificationShownBlock()
	}
}
