//
//  InboxServiceTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 04.05.2022.
//

import XCTest
import Foundation
@testable import MobileMessaging

final class InboxServiceTests: MMTestCase {
    func testThatAccessTokenPassedInAuthorizationHeader() {
        MMTestCase.startWithCorrectApplicationCode()
        weak var requestVerified = self.expectation(description: "requestVerified")
        weak var inboxFetched = self.expectation(description: "inboxFetched")
        
        let remoteApiProvider = RemoteAPIProvider(sessionManager: SessionManagerStubBase(getDataResponseClosure: { requestData, completion in
            if let getInboxRequest = requestData as? GetInbox {
                XCTAssertEqual(getInboxRequest.headers!["Authorization"]!, "Bearer givenAccessToken")
                requestVerified?.fulfill()
            }
            completion(nil, nil)
            return true
        }))
        
        mobileMessagingInstance.remoteApiProvider = remoteApiProvider
        
        MobileMessaging.inbox?.fetchInbox(token: "givenAccessToken", externalUserId: "user1", options: nil, completion: { inbox, error in
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatAppCodePassedInAuthorizationHeader() {
        MMTestCase.startWithCorrectApplicationCode()
        weak var requestVerified = self.expectation(description: "requestVerified")
        weak var inboxFetched = self.expectation(description: "inboxFetched")
        
        let remoteApiProvider = RemoteAPIProvider(sessionManager: SessionManagerStubBase(getDataResponseClosure: { requestData, completion in
            if let getInboxRequest = requestData as? GetInbox {
                XCTAssertEqual(getInboxRequest.headers!["Authorization"]!, "App \(MMTestConstants.kTestCorrectApplicationCode)")
                requestVerified?.fulfill()
            }
            completion(nil, nil)
            return true
        }))
        
        mobileMessagingInstance.remoteApiProvider = remoteApiProvider
        
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: nil, completion: { inbox, error in
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatMessageIsMarkedAsSeenOnlyOnce() {
        MMTestCase.startWithCorrectApplicationCode()
        weak var messagesMarkedAsSeen = self.expectation(description: "sendSeenStatus called once")
        var sendSeenStatusCallCount = 0
        
        let remoteApiProvider = RemoteAPIProviderStub()
        remoteApiProvider.sendSeenStatusClosure = { (_, _, body) -> SeenStatusSendingResult in
            sendSeenStatusCallCount += 1
            let requestBody = body as RequestBody
            let messageIds = requestBody.extractMessageIdsFromRequestBody()
            
            XCTAssertEqual(messageIds, ["1", "2"])
            if sendSeenStatusCallCount == 1 {
                messagesMarkedAsSeen?.fulfill()
            }
            return SeenStatusSendingResult.Success(EmptyResponse())
        }
        
        mobileMessagingInstance.remoteApiProvider = remoteApiProvider
        MobileMessaging.inbox?.setSeen(externalUserId: "user1", messageIds: ["1", "2"], completion: { result in })
        MobileMessaging.inbox?.setSeen(externalUserId: "user1", messageIds: ["1", "2"], completion: { result in })
        
        waitForExpectations(timeout: 15, handler: nil)
        XCTAssertEqual(sendSeenStatusCallCount, 1, "sendSeenStatus should only be called once for the same message ID")
    }
    
    func testThatMessageIsNotMarkedAsSeenInCaseOfError() {
        MMTestCase.startWithCorrectApplicationCode()
        weak var messagesMarkedAsSeen = self.expectation(description: "sendSeenStatus called")
        
        let failRemoteApiProvider = RemoteAPIProviderStub()
        failRemoteApiProvider.sendSeenStatusClosure = { (_, _, body) -> SeenStatusSendingResult in
            let requestBody = body as RequestBody
            let messageIds = requestBody.extractMessageIdsFromRequestBody()
            
            XCTAssertEqual(messageIds, ["1", "2"])
            
            return SeenStatusSendingResult.Failure(NSError())
        }
        
        let successRemoteApiProvider = RemoteAPIProviderStub()
        successRemoteApiProvider.sendSeenStatusClosure = { (_, _, body) -> SeenStatusSendingResult in
            let requestBody = body as RequestBody
            let messageIds = requestBody.extractMessageIdsFromRequestBody()
            
            XCTAssertEqual(messageIds, ["1", "2"])
            messagesMarkedAsSeen?.fulfill()
            return SeenStatusSendingResult.Success(EmptyResponse())
        }
        
        mobileMessagingInstance.remoteApiProvider = failRemoteApiProvider
        MobileMessaging.inbox?.setSeen(externalUserId: "user1", messageIds: ["1", "2"], completion: { result in })
        mobileMessagingInstance.remoteApiProvider = successRemoteApiProvider
        MobileMessaging.inbox?.setSeen(externalUserId: "user1", messageIds: ["1", "2"], completion: { result in })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
}

extension Dictionary where Key == String, Value == Any {
    func extractMessageIdsFromRequestBody() -> [String] {
        let messages = self["messages"] as? [[String: Any]]
        return messages!.compactMap{ $0["messageId"] as? String }
    }
}
