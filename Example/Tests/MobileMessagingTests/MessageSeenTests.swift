//
//  MessageSeenTests.swift
//  MobileMessaging
//
//  Created by okoroleva on 14.04.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
import CoreData
@testable import MobileMessaging

class SeenTestsRemoteAPI : MMRemoteAPIQueue {
    var testCompletion : (TestResult) -> Void
    var testCompletionWithRequest : ((MMPostSeenMessagesRequest) -> Void)?
    
    init(baseURLString: String, appCode: String, testCompletion: (TestResult) -> Void, testCompletionWithRequest: ((MMPostSeenMessagesRequest) -> Void)? = nil) {
        self.testCompletion = testCompletion
        self.testCompletionWithRequest = testCompletionWithRequest
        super.init(baseURL: baseURLString, applicationCode: appCode)
    }
    
    override func performRequest<R: MMHTTPRequestData>(request: R, completion: (Result<R.ResponseType>) -> Void) {
        
        if let request = request as? MMPostSeenMessagesRequest {
            self.testCompletionWithRequest?(request)
        }
        
        let requestOperation = MMRetryableRequestOperation<R>(request: request, applicationCode: applicationCode, baseURL: baseURL) { requestResult in
            completion(requestResult)
            
            var testResult : TestResult
            switch requestResult {
            case .Success:
                testResult = TestResult.Success()
            case .Failure(let error):
                testResult = TestResult.Failure(error: error)
			case .Cancel:
				testResult = TestResult.Cancel
            }
            
            self.testCompletion(testResult)
        }
        queue.cancelAllOperations()
        queue.addOperation(requestOperation)
    }
}


class MessageSeenTests: MMTestCase {
	
	func testSendSeenStatusInDB() {
		let expSeenStatusInDB = expectationWithDescription("SeenStatusInDB")
		let seenMessageIds = ["m1"]
		let messagesCtx = storage.mainThreadManagedObjectContext
		let remoteApi = MMRemoteAPIQueue(baseURL: MMTestConstants.kTestBaseURLString, applicationCode: MMTestConstants.kTestCorrectApplicationCode)
		let seenRemoteApi = SeenTestsRemoteAPI(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestCorrectApplicationCode, testCompletion:{ _ -> Void in
			let message = MessageManagedObject.MR_findFirstWithPredicate(NSPredicate(format:"messageId == %@", "m1"), inContext: messagesCtx)
			XCTAssertNotNil(message)
			XCTAssertEqual(message.seenStatus, MMSeenStatus.SeenSent, "\(seenMessageIds) must me seen and sent")
			
			expSeenStatusInDB.fulfill()
		})
		let messageHandler: MMMessageHandler = MMMessageHandler(storage: self.storage, remoteApi: remoteApi, seenSenderRemoteAPI: seenRemoteApi)
		
		messageHandler.messageHandlingQueue.addOperationWithBlock {
			messageHandler.storageContext.performBlockAndWait{
				self.createDBMessages(seenMessageIds, seenStatus: .NotSeen, context: messageHandler.storageContext)
				messageHandler.save()
			}
		}
		
		messageHandler.setSeen(seenMessageIds)
		
		self.waitForExpectationsWithTimeout(100, handler: nil)
	}
	
    func testSendEmpty() {
        let expResponseCheck = expectationWithDescription("response")
        
        let request = MMPostSeenMessagesRequest(seenList: [])
        let seenRemoteApi = MMRemoteAPIQueue(baseURL: MMTestConstants.kTestBaseURLString, applicationCode: MMTestConstants.kTestCorrectApplicationCode)
        
        seenRemoteApi.performRequest(request) { (result) in
            switch result {
            case .Success:
                XCTAssert(false, "Not expected success response")
            case .Failure(let error):
                XCTAssert(error?.localizedDescription == "Empty message seen data", "Not expected error \(error?.localizedDescription)")
			case .Cancel:
				 XCTAssert(false, "Not expected cancel")
			}
			
            expResponseCheck.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(100, handler: nil)
    }
    
	/*
    - setSeen (m1, m2, m3)
    nothing to add from DB
    **/
    func testSendSeenSuccess() {
        let expRequestCheck = expectationWithDescription("request")
        let expResponseCheck = expectationWithDescription("response")

        let seenMessageIds = ["m1", "m2", "m3"]
        let remoteApi = MMRemoteAPIQueue(baseURL: MMTestConstants.kTestBaseURLString, applicationCode: MMTestConstants.kTestCorrectApplicationCode)
        let seenRemoteApi = getSeenRemoteApi(seenMessageIds, expRequestCheck: expRequestCheck, expResponseCheck: expResponseCheck)
        let messageHandler: MMMessageHandler = MMMessageHandler(storage: self.storage, remoteApi: remoteApi, seenSenderRemoteAPI: seenRemoteApi)
		
		messageHandler.messageHandlingQueue.addOperationWithBlock {
			messageHandler.storageContext.performBlockAndWait{
				self.createDBMessages(seenMessageIds, seenStatus: .NotSeen, context: messageHandler.storageContext)
				messageHandler.save()
			}
		}
		
        messageHandler.setSeen(seenMessageIds)
        
        self.waitForExpectationsWithTimeout(100, handler: nil)
    }
    
    func testSendSeenWithDBAdditionalSeens() {
        let expRequestCheck = expectationWithDescription("request")
        let expResponseCheck = expectationWithDescription("response")
        
        let seenMessageIds = ["m1", "m2"]
        let seenStatusSentMessageIdsInDB = ["m3", "m4"]
        let seenStatusNotSentMessageIdsInDB = ["m5", "m6"]
        
        let remoteApi = MMRemoteAPIQueue(baseURL: MMTestConstants.kTestBaseURLString, applicationCode: MMTestConstants.kTestCorrectApplicationCode)
        let seenRemoteApi = getSeenRemoteApi(seenMessageIds + seenStatusNotSentMessageIdsInDB, expRequestCheck: expRequestCheck, expResponseCheck: expResponseCheck)
        let messageHandler: MMMessageHandler = MMMessageHandler(storage: self.storage, remoteApi: remoteApi, seenSenderRemoteAPI: seenRemoteApi)
		
		messageHandler.messageHandlingQueue.addOperationWithBlock {
			messageHandler.storageContext.performBlockAndWait {
				
				self.createDBMessages(seenMessageIds, seenStatus: .NotSeen, context: messageHandler.storageContext)
				self.createDBMessages(seenStatusSentMessageIdsInDB, seenStatus: .SeenSent, context: messageHandler.storageContext)
				self.createDBMessages(seenStatusNotSentMessageIdsInDB, seenStatus: .SeenNotSent, context: messageHandler.storageContext)
				
				messageHandler.save()
			}
		}
		
        messageHandler.setSeen(seenMessageIds)
        
        self.waitForExpectationsWithTimeout(100, handler: nil)
    }

    func testSendSeenAgain() {
        let expRequestCheck = expectationWithDescription("request")
        let expResponseCheck = expectationWithDescription("response")
        
        let seenMessageIds = ["m1", "m3"]
        let seenStatusSentMessageIdsInDB = ["m1", "m2"]
        
        let creationDate = NSDate()
        
        let remoteApi = MMRemoteAPIQueue(baseURL: MMTestConstants.kTestBaseURLString, applicationCode: MMTestConstants.kTestCorrectApplicationCode)
        let seenRemoteApi = getSeenRemoteApi(seenMessageIds, datesToCheck: ["m1": creationDate], expRequestCheck: expRequestCheck, expResponseCheck: expResponseCheck)
        let messageHandler: MMMessageHandler = MMMessageHandler(storage: self.storage, remoteApi: remoteApi, seenSenderRemoteAPI: seenRemoteApi)
		
		messageHandler.storageContext.performBlockAndWait {
			
			self.createDBMessages(seenStatusSentMessageIdsInDB, date: creationDate, seenStatus: .SeenSent, context: messageHandler.storageContext)
			self.createDBMessages(["m3"], date: creationDate, seenStatus: .NotSeen, context: messageHandler.storageContext)
			
			messageHandler.save()
		}
		
        //delay for check that date not changed after setSeen
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            messageHandler.setSeen(seenMessageIds)
        }
        
        self.waitForExpectationsWithTimeout(100, handler: nil)
    }
    
    func testSendFailureInvalidAppId() {
        let expResponseCheck = expectationWithDescription("response")
        let seenMessageIds = ["m1", "m3"]
        let remoteApi = MMRemoteAPIQueue(baseURL: MMTestConstants.kTestBaseURLString, applicationCode: MMTestConstants.kTestCorrectApplicationCode)
        let seenRemoteApi = SeenTestsRemoteAPI(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestWrongApplicationCode, testCompletion:{ (result) -> Void in
            switch result {
            case .Success:
                XCTAssert(false, "Not expected success response")
            case .Failure(let error):
                XCTAssert(error?.localizedDescription == "Invalid Application Id", "Not expected error \(error?.localizedDescription)")
			case .Cancel: break
            }
            expResponseCheck.fulfill()
        })
        
        let messageHandler: MMMessageHandler = MMMessageHandler(storage: self.storage, remoteApi: remoteApi, seenSenderRemoteAPI: seenRemoteApi)
		
		messageHandler.messageHandlingQueue.addOperationWithBlock {
			messageHandler.storageContext.performBlockAndWait {
				self.createDBMessages(seenMessageIds, seenStatus: .NotSeen, context: messageHandler.storageContext)
				messageHandler.save()
			}
		}
		
        messageHandler.setSeen(seenMessageIds)
        
        self.waitForExpectationsWithTimeout(100, handler: nil)
    }
	
    //MARK: Utils
	private func getSeenRemoteApi(messageIdsToCheck: [String], datesToCheck: [String: NSDate]? = nil, expRequestCheck: XCTestExpectation, expResponseCheck: XCTestExpectation) -> SeenTestsRemoteAPI {
        return SeenTestsRemoteAPI(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestCorrectApplicationCode, testCompletion: { (result) -> Void in
            
            switch result {
			case .Failure(let error):
                XCTAssertNil(error, "Request failed with error")
			case .Cancel:
				XCTAssert(false, "Unexpected cancel")
			default: break
            }
            expResponseCheck.fulfill()
            
            }) { request in
                let messageIds = request.seenList.flatMap{ $0.messageId }
                let mIdsToCheck = Set(messageIds)
                let mIds = Set(messageIdsToCheck)
                let diff = mIdsToCheck.exclusiveOr(mIds)
                XCTAssert(diff.count == 0, "Unexpected count of send seen statuses \(mIdsToCheck) should be \(mIds)")
                
                if let datesToCheck = datesToCheck {
                    for seendData in request.seenList {
                        if let date = datesToCheck[seendData.messageId] {
                            XCTAssertEqual(seendData.seenTimestamp, date.timeIntervalSince1970, "Expected date differ from actual for message")
                        }
                    }
                }
                expRequestCheck.fulfill()
        }
    }
    
    private func createDBMessages(messageIds: [String], date: NSDate = NSDate(), seenStatus: MMSeenStatus, context: NSManagedObjectContext) {
        var newMsg : MessageManagedObject
        for id in messageIds {
            if let newMsgObj = MessageManagedObject.MR_findFirstWithPredicate(NSPredicate(format: "messageId == %@", id), inContext: context) {
                newMsg = newMsgObj
            } else {
                newMsg = MessageManagedObject.MR_createEntityInContext(context)
                newMsg.messageId = id
                newMsg.creationDate = date
            }
            newMsg.seenStatus = seenStatus
            newMsg.seenDate = date
        }
    }
}
