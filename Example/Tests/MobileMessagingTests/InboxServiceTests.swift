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
    
}
