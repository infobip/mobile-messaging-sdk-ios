// 
//  Example/Tests/MobileMessagingTests/InboxServiceTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
    
    func testThatMultipleTopicsFilteringWorksClientSide() {
        MMTestCase.startWithCorrectApplicationCode()
        weak var inboxFetched = self.expectation(description: "inboxFetched")
        
        let serverResponse = MMInbox(json: JSON.parse("""
        {
          "messages": [
            {
              "messageId": "msg1",
              "internalData": {
                "campaignId": "campaign1",
                "inApp": false,
                "sendDateTime": 1643314503233,
                "inbox": {
                  "seen": false,
                  "topic": "sports"
                }
              },
              "aps": {
                "sound": "default",
                "alert": {
                  "title": "Sports News",
                  "body": "Latest sports update"
                }
              },
              "silent": false
            },
            {
              "messageId": "msg2",
              "internalData": {
                "campaignId": "campaign2",
                "inApp": false,
                "sendDateTime": 1643314503234,
                "inbox": {
                  "seen": true,
                  "topic": "weather"
                }
              },
              "aps": {
                "sound": "default",
                "alert": {
                  "title": "Weather Alert",
                  "body": "Rain expected"
                }
              },
              "silent": false
            },
            {
              "messageId": "msg3",
              "internalData": {
                "campaignId": "campaign3",
                "inApp": false,
                "sendDateTime": 1643314503235,
                "inbox": {
                  "seen": false,
                  "topic": "news"
                }
              },
              "aps": {
                "sound": "default",
                "alert": {
                  "title": "Breaking News",
                  "body": "Important announcement"
                }
              },
              "silent": false
            }
          ],
          "countTotal": 10,
          "countUnread": 5
        }
        """))!
        
        let remoteApiProvider = RemoteAPIProvider(sessionManager: SessionManagerStubBase(getDataResponseClosure: { requestData, completion in
            if let getInboxRequest = requestData as? GetInbox {
                // Verify that when multiple topics are used, no topic filter is sent to server
                XCTAssertNil(getInboxRequest.parameters?[MMConsts.InboxKeys.messageTopic])
                // Verify that limit is set to 1000 for multiple topics fetching
                XCTAssertEqual(getInboxRequest.parameters?[MMConsts.InboxKeys.limit] as? String, "1000")
            }
            
            let responseDict: [String: Any] = [
                "messages": serverResponse.messages.map { message in
                    return [
                        "messageId": message.messageId,
                        "internalData": [
                            "campaignId": "campaign",
                            "inApp": false,
                            "sendDateTime": Int64(message.sendDateTime * 1000),
                            "inbox": [
                                "seen": message.seenStatus != .NotSeen,
                                "topic": message.topic ?? ""
                            ]
                        ],
                        "aps": [
                            "sound": "default",
                            "alert": [
                                "title": message.title ?? "",
                                "body": message.text ?? ""
                            ]
                        ],
                        "silent": false
                    ]
                },
                "countTotal": serverResponse.countTotal,
                "countUnread": serverResponse.countUnread
            ]
            
            completion(JSON(responseDict), nil)
            return true
        }))
        
        mobileMessagingInstance.remoteApiProvider = remoteApiProvider
        
        let filterOptions = MMInboxFilterOptions(
            fromDateTime: nil,
            toDateTime: nil,
            topics: ["sports", "weather"],
            limit: 2
        )
        
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: filterOptions, completion: { inbox, error in
            XCTAssertNil(error)
            XCTAssertNotNil(inbox)
            
            // Verify client-side filtering worked
            XCTAssertEqual(inbox!.messages.count, 2) // Limited to 2 after filtering
            XCTAssertEqual(inbox!.countTotal, 10) // Original server counts
            XCTAssertEqual(inbox!.countUnread, 5) // Original server counts
            XCTAssertEqual(inbox!.countTotalFiltered, 2) // Filtered count
            XCTAssertEqual(inbox!.countUnreadFiltered, 1) // Filtered unread count
            
            // Verify only sports and weather messages are returned
            let topics = inbox!.messages.compactMap { $0.topic }
            XCTAssertTrue(topics.contains("sports"))
            XCTAssertTrue(topics.contains("weather"))
            XCTAssertFalse(topics.contains("news"))
            
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatMultipleTopicsReturnsAllMessagesWhenNoLimitSpecified() {
        MMTestCase.startWithCorrectApplicationCode()
        weak var inboxFetched = self.expectation(description: "inboxFetched")
        
        var messages: [[String: Any]] = []
        for i in 1...30 {
            messages.append([
                "messageId": "msg\(i)",
                "internalData": [
                    "campaignId": "campaign\(i)",
                    "inApp": false,
                    "sendDateTime": 1643314503233 + i,
                    "inbox": [
                        "seen": i % 2 == 0,
                        "topic": "sports"
                    ]
                ],
                "aps": [
                    "sound": "default",
                    "alert": [
                        "title": "Message \(i)",
                        "body": "Content \(i)"
                    ]
                ],
                "silent": false
            ])
        }
        
        let serverResponseDict: [String: Any] = [
            "messages": messages,
            "countTotal": 100,
            "countUnread": 50
        ]
        
        let serverResponse = MMInbox(json: JSON(serverResponseDict))!
        
        let remoteApiProvider = RemoteAPIProvider(sessionManager: SessionManagerStubBase(getDataResponseClosure: { requestData, completion in
            let responseDict: [String: Any] = [
                "messages": serverResponse.messages.map { message in
                    return [
                        "messageId": message.messageId,
                        "internalData": [
                            "campaignId": "campaign",
                            "inApp": false,
                            "sendDateTime": Int64(message.sendDateTime * 1000),
                            "inbox": [
                                "seen": message.seenStatus != .NotSeen,
                                "topic": message.topic ?? ""
                            ]
                        ],
                        "aps": [
                            "sound": "default",
                            "alert": [
                                "title": message.title ?? "",
                                "body": message.text ?? ""
                            ]
                        ],
                        "silent": false
                    ]
                },
                "countTotal": serverResponse.countTotal,
                "countUnread": serverResponse.countUnread
            ]
            
            completion(JSON(responseDict), nil)
            return true
        }))
        
        mobileMessagingInstance.remoteApiProvider = remoteApiProvider
        
        let filterOptions = MMInboxFilterOptions(
            fromDateTime: nil,
            toDateTime: nil,
            topics: ["sports"],
            limit: nil
        )
        
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: filterOptions, completion: { inbox, error in
            XCTAssertNil(error)
            XCTAssertNotNil(inbox)
            
            // Should return ALL 30 messages when no limit is specified (no default limit when using topics array)
            XCTAssertEqual(inbox!.messages.count, 30)
            XCTAssertEqual(inbox!.countTotalFiltered, 30) // All 30 matched the filter
            XCTAssertEqual(inbox!.countUnreadFiltered, 15) // 15 out of 30 are unread
            
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatMultipleTopicsRespectsLimitWhenSpecified() {
        MMTestCase.startWithCorrectApplicationCode()
        weak var inboxFetched = self.expectation(description: "inboxFetched")
        
        var messages: [[String: Any]] = []
        for i in 1...25 {
            messages.append([
                "messageId": "msg\(i)",
                "internalData": [
                    "campaignId": "campaign\(i)",
                    "inApp": false,
                    "sendDateTime": 1643314503233 + i,
                    "inbox": [
                        "seen": i % 3 == 0, // Every 3rd message is seen
                        "topic": "sports"
                    ]
                ],
                "aps": [
                    "sound": "default",
                    "alert": [
                        "title": "Message \(i)",
                        "body": "Content \(i)"
                    ]
                ],
                "silent": false
            ])
        }
        
        let serverResponseDict: [String: Any] = [
            "messages": messages,
            "countTotal": 100,
            "countUnread": 50
        ]
        
        let serverResponse = MMInbox(json: JSON(serverResponseDict))!
        
        let remoteApiProvider = RemoteAPIProvider(sessionManager: SessionManagerStubBase(getDataResponseClosure: { requestData, completion in
            let responseDict: [String: Any] = [
                "messages": serverResponse.messages.map { message in
                    return [
                        "messageId": message.messageId,
                        "internalData": [
                            "campaignId": "campaign",
                            "inApp": false,
                            "sendDateTime": Int64(message.sendDateTime * 1000),
                            "inbox": [
                                "seen": message.seenStatus != .NotSeen,
                                "topic": message.topic ?? ""
                            ]
                        ],
                        "aps": [
                            "sound": "default",
                            "alert": [
                                "title": message.title ?? "",
                                "body": message.text ?? ""
                            ]
                        ],
                        "silent": false
                    ]
                },
                "countTotal": serverResponse.countTotal,
                "countUnread": serverResponse.countUnread
            ]
            
            completion(JSON(responseDict), nil)
            return true
        }))
        
        mobileMessagingInstance.remoteApiProvider = remoteApiProvider
        
        let filterOptions = MMInboxFilterOptions(
            fromDateTime: nil,
            toDateTime: nil,
            topics: ["sports"],
            limit: 10 // Limit specified, should return only 10 messages
        )
        
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: filterOptions, completion: { inbox, error in
            XCTAssertNil(error)
            XCTAssertNotNil(inbox)
            
            // Should return only 10 messages due to limit, even though 25 match
            XCTAssertEqual(inbox!.messages.count, 10)
            XCTAssertEqual(inbox!.countTotalFiltered, 25) // All 25 matched the filter (before limit)
            // 17 out of 25 are unread (since every 3rd is seen: 8 seen, 17 unread)
            XCTAssertEqual(inbox!.countUnreadFiltered, 17)
            
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
}

extension Dictionary where Key == String, Value == Any {
    func extractMessageIdsFromRequestBody() -> [String] {
        let messages = self["messages"] as? [[String: Any]]
        return messages!.compactMap{ $0["messageId"] as? String }
    }
}
