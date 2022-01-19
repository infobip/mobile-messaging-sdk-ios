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
		MMTestCase.startWithApplicationCode(SyncTestAppIds.kCorrectIdNothingToSynchronize)
		
		weak var expectation = self.expectation(description: "Sync finished")
		XCTAssertEqual(MMTestCase.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 0, "There must be not any stored message")
		
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		mobileMessagingInstance.messageHandler.syncWithServer(userInitiated: true) { error in
			
			XCTAssertNil(error)
			XCTAssertEqual(MMTestCase.nonReportedStoredMessagesCount(self.storage.mainThreadManagedObjectContext!), 0, "There must be not any stored message")
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
		
		MMTestCase.startWithApplicationCode(SyncTestAppIds.kCorrectIdMergeSynchronization)
		
		//Precondiotions
		mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": "m2"],  completion: { _ in
			prepconditionExpectation?.fulfill()
			
			//Actions
			self.mobileMessagingInstance.setSeen(userInitiated: true, messageIds: ["m2"], immediately: false, completion: {
				seenExpectation?.fulfill()
			})
		})
		
        mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": "m1"],  completion: { _ in
			newMsgExpectation?.fulfill()
		})
		
		mobileMessagingInstance.messageHandler.syncWithServer(userInitiated: true) { error in
			syncExpectation?.fulfill()
		}
		
		//Expectations
		waitForExpectations(timeout: 60) { error in
			let ctx = self.storage.mainThreadManagedObjectContext!
			ctx.reset()
			ctx.performAndWait {
				if let messages = MessageManagedObject.MM_findAllInContext(ctx) {
					let m1 = messages.filter({$0.messageId == "m1"}).first
					let m2 = messages.filter({$0.messageId == "m2"}).first
					XCTAssertEqual(m2?.seenStatus, MMSeenStatus.SeenNotSent, "m2 must be seen and synced")
					XCTAssertEqual(m2?.reportSent, true, "m2 delivery report must be delivered")
					XCTAssertEqual(m1?.seenStatus, MMSeenStatus.NotSeen, "m1 must be not seen")
					XCTAssertEqual(m1?.reportSent, true, "m1 delivery report must be delivered")
				} else {
					XCTFail("There should be some messages in database")
				}
			}
		}
	}
}

class FetchMessagesCompletionTests: MMTestCase {

	func testThatNewDataFetched() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        
		weak var exp = expectation(description: "Handler called")
		let apiProvider = RemoteAPIProviderStub()
		apiProvider.syncMessagesClosure = { appcode, pushRegistrationId, body -> MessagesSyncResult in
			if ((body["drIDs"] as? [String]) ?? [String]()) == ["newData"]  {
				return MessagesSyncResult.Success(MessagesSyncResponse(json: JSON(["payloads": [["aps": ["key":"value"], "messageId": "mId2"]]]))!)
			} else {
				return MessagesSyncResult.Success(MessagesSyncResponse(json: JSON(["payloads": []]))!)
			}
		}
		self.mobileMessagingInstance.remoteApiProvider = apiProvider

		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": "newData"],  completion: { result in
			XCTAssertEqual(result.backgroundFetchResult, .newData)
			exp?.fulfill()
		})
		
		waitForExpectations(timeout: 10) {_ in }
	}
    
    func testThatLocalNotificationScheduled() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        
        weak var messageHandled = expectation(description: "messageHandled")
        weak var localNotificationScheduled = expectation(description: "localNotificationScheduled")
        let messageHandlingDelegateMock = MessageHandlingDelegateMock()
        messageHandlingDelegateMock.willScheduleLocalNotification = { m in
            localNotificationScheduled?.fulfill()
        }

        MobileMessaging.messageHandlingDelegate = messageHandlingDelegateMock

		let apiProvider = RemoteAPIProviderStub()
		apiProvider.syncMessagesClosure = { appcode, pushRegistrationId, body -> MessagesSyncResult in
			if ((body["drIDs"] as? [String]) ?? [String]()) == ["newData"]  {
				return MessagesSyncResult.Success(MessagesSyncResponse(json: JSON(["payloads": [["aps": ["key":"value"], "messageId": "mId2"]]]))!)
			} else {
				return MessagesSyncResult.Success(MessagesSyncResponse(json: JSON(["payloads": []]))!)
			}
		}
        self.mobileMessagingInstance.remoteApiProvider = apiProvider

        mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": "newData"],  completion: { result in
            XCTAssertEqual(result.backgroundFetchResult, .newData)
            messageHandled?.fulfill()
        })
        
        waitForExpectations(timeout: 10) {_ in }
    }
	
	func testThatNoDataFetched() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        
		weak var exp = expectation(description: "Handler called")

		let apiProvider = RemoteAPIProviderStub()
		apiProvider.syncMessagesClosure = { appcode, pushRegistrationId, body -> MessagesSyncResult in
				return MessagesSyncResult.Success(MessagesSyncResponse(json: JSON(["payloads": []]))!)
		}
		self.mobileMessagingInstance.remoteApiProvider = apiProvider

		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": "noData"],  completion: { result in
			XCTAssertEqual(result.backgroundFetchResult, .noData)
			exp?.fulfill()
		})
		
		waitForExpectations(timeout: 10) {_ in }
	}
	
	func testThatDataFetchFailed() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        
		weak var exp = expectation(description: "Handler called")
		let apiProvider = RemoteAPIProviderStub()
		apiProvider.syncMessagesClosure = { appcode, pushRegistrationId, body -> MessagesSyncResult in
			return MessagesSyncResult.Failure(NSError(type: MMInternalErrorType.UnknownError))
		}
		self.mobileMessagingInstance.remoteApiProvider = apiProvider

		mobileMessagingInstance.didReceiveRemoteNotification(userInitiated: true, userInfo: ["aps": ["key":"value"], "messageId": "Failed"],  completion: { result in
			XCTAssertEqual(result.backgroundFetchResult, .failed)
			XCTAssertNotNil(result.error)
			XCTAssertEqual(result.error, NSError(type: MMInternalErrorType.UnknownError))
			exp?.fulfill()
		})
		
		waitForExpectations(timeout: 10) {_ in }
	}
}
