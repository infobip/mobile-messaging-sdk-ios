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
    /// Inbox requests require a server-issued registration ID, independently of APNs permission/token state.
    private func startRegisteredSdk() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
    }

    func testThatAccessTokenPassedInAuthorizationHeader() {
        startRegisteredSdk()
        weak let requestVerified = self.expectation(description: "requestVerified")
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        
        let remoteApiProvider = RemoteAPIProvider(sessionManager: SessionManagerStubBase(getDataResponseClosure: { requestData, completion in
            guard InboxServiceTests.isInboxRequest(requestData) else { return false }
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
        startRegisteredSdk()
        weak let requestVerified = self.expectation(description: "requestVerified")
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        
        let remoteApiProvider = RemoteAPIProvider(sessionManager: SessionManagerStubBase(getDataResponseClosure: { requestData, completion in
            guard InboxServiceTests.isInboxRequest(requestData) else { return false }
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
        startRegisteredSdk()
        weak let messagesMarkedAsSeen = self.expectation(description: "sendSeenStatus called once")
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
    
    func testAsyncSetSeenSendsOnlyUnseenMessagesAndAllowsRetryAfterFailure() {
        startRegisteredSdk()
        let inbox = MobileMessaging.inbox!
        let completed = expectation(description: "Async setSeen")
        var sentMessageIds: [[String]] = []
        let remoteApiProvider = RemoteAPIProviderStub()
        remoteApiProvider.sendSeenStatusClosure = { (_, _, body) -> SeenStatusSendingResult in
            sentMessageIds.append(body.extractMessageIdsFromRequestBody())
            return sentMessageIds.count == 2 ? .Failure(self.serverError("INTERNAL_SERVER_ERROR")) : .Success(EmptyResponse())
        }
        mobileMessagingInstance.remoteApiProvider = remoteApiProvider

        Task {
            try await inbox.setSeen(externalUserId: "user1", messageIds: ["1", "2"])
            // Already seen: no request.
            try await inbox.setSeen(externalUserId: "user1", messageIds: ["1"])
            // Only the new message is sent; the failure releases it.
            do {
                try await inbox.setSeen(externalUserId: "user1", messageIds: ["2", "3"])
                XCTFail("Expected server error")
            } catch {
                XCTAssertEqual((error as NSError).mm_code, "INTERNAL_SERVER_ERROR")
            }
            try await inbox.setSeen(externalUserId: "user1", messageIds: ["3"])
            completed.fulfill()
        }
        waitForExpectations(timeout: 15, handler: nil)
        XCTAssertEqual(sentMessageIds, [["1", "2"], ["3"], ["3"]])
    }

    func testSetSeenCompletionIsCalledOnMainEvenWhenNothingIsSent() {
        startRegisteredSdk()
        let inbox = MobileMessaging.inbox!
        let remoteApiProvider = RemoteAPIProviderStub()
        remoteApiProvider.sendSeenStatusClosure = { (_, _, _) -> SeenStatusSendingResult in .Success(EmptyResponse()) }
        mobileMessagingInstance.remoteApiProvider = remoteApiProvider
        let first = expectation(description: "first")
        let second = expectation(description: "second, nothing to send")
        DispatchQueue.global().async {
            inbox.setSeen(externalUserId: "user1", messageIds: ["1"]) { error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                first.fulfill()
                DispatchQueue.global().async {
                    inbox.setSeen(externalUserId: "user1", messageIds: ["1"]) { error in
                        XCTAssertTrue(Thread.isMainThread)
                        XCTAssertNil(error)
                        second.fulfill()
                    }
                }
            }
        }
        waitForExpectations(timeout: 15, handler: nil)
    }

    func testThatMessageIsNotMarkedAsSeenInCaseOfError() {
        startRegisteredSdk()
        weak let messagesMarkedAsSeen = self.expectation(description: "sendSeenStatus called")
        
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
        startRegisteredSdk()
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        
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
            guard InboxServiceTests.isInboxRequest(requestData) else { return false }
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
        startRegisteredSdk()
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        
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
            guard InboxServiceTests.isInboxRequest(requestData) else { return false }
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
        startRegisteredSdk()
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        
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
            guard InboxServiceTests.isInboxRequest(requestData) else { return false }
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
    
    // MARK: - Registration readiness

    func testFetchAndDeleteRequireANonblankRegistrationForBothAuthorizationModes() {
        MMTestCase.startWithCorrectApplicationCode()
        let inbox = MobileMessaging.inbox!
        installSessionManagerStub { _, completion in
            XCTFail("No request is allowed before registration is available")
            completion(nil, nil)
        }
        for registration in [nil, "", " \t\n"] as [String?] {
            mobileMessagingInstance.pushRegistrationId = registration
            let options: [MMInboxFilterOptions?] = [
                nil,
                MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: "Offers", limit: 5, cursor: "next"),
                MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topics: ["Offers", "News"], limit: 5)
            ]
            for filter in options {
                expectNoRegistration { completion in
                    inbox.fetchInbox(token: "jwt", externalUserId: "user", options: filter) { result, error in
                        XCTAssertNil(result)
                        completion(error)
                    }
                }
                expectNoRegistration { completion in
                    inbox.fetchInbox(externalUserId: "user", options: filter) { result, error in
                        XCTAssertNil(result)
                        completion(error)
                    }
                }
            }
            expectNoRegistration {
                inbox.deleteMessages(token: "jwt", externalUserId: "user", messageIds: ["id"], completion: $0)
            }
            expectNoRegistration {
                inbox.deleteMessages(externalUserId: "user", messageIds: ["id"], completion: $0)
            }
            // Finish calls for this registration state before changing it.
            waitForExpectations(timeout: 15, handler: nil)
        }
    }

    private func expectNoRegistration(_ operation: @escaping (@escaping (NSError?) -> Void) -> Void) {
        let completed = expectation(description: "No registration")
        completed.assertForOverFulfill = true
        DispatchQueue.global().async {
            operation { error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(error?.domain, MMInternalErrorDomain)
                XCTAssertEqual(error?.code, NSError(type: .NoRegistration).code)
                XCTAssertNil(error?.mm_code)
                completed.fulfill()
            }
        }
    }

    func testInputValidationPrecedesTheRegistrationGuard() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = nil
        let inbox = MobileMessaging.inbox!
        installSessionManagerStub { _, completion in
            XCTFail("Invalid input must not send a request")
            completion(nil, nil)
        }
        expectLocalValidation("JWT token must not be blank.") { completion in
            inbox.fetchInbox(token: " ", externalUserId: "user", options: nil) { _, error in completion(error) }
        }
        expectLocalValidation("External user ID must not be blank.") { completion in
            inbox.fetchInbox(externalUserId: " ", options: nil) { _, error in completion(error) }
        }
        expectLocalValidation("Cursor pagination is not supported with a nonempty topics array; use the singular topic option instead.") { completion in
            let options = MMInboxFilterOptions(dictRepresentation: ["topics": ["Offers"], "cursor": "next"])
            inbox.fetchInbox(externalUserId: "user", options: options) { _, error in completion(error) }
        }
        expectLocalValidation("At least one message identifier is required.") {
            inbox.deleteMessages(externalUserId: "user", messageIds: [], completion: $0)
        }
        expectLocalValidation("Message identifiers must not be blank.") {
            inbox.deleteMessages(token: "jwt", externalUserId: "user", messageIds: [" "], completion: $0)
        }
        waitForExpectations(timeout: 15, handler: nil)
    }

    func testFetchAndDeleteCanBeRetriedAfterRegistrationCompletes() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = nil
        let inbox = MobileMessaging.inbox!
        let completed = expectation(description: "Registered inbox operations succeed")
        var requestCount = 0
        mobileMessagingInstance.remoteApiProvider = RemoteAPIProvider(sessionManager: QueueHonoringSessionManagerStub { request in
            requestCount += 1
            XCTAssertTrue(request is GetInbox || request is DeleteInboxMessages)
            XCTAssertEqual(request.headers?["Authorization"], "Bearer jwt")
            return (nil, nil)
        })
        inbox.fetchInbox(token: "jwt", externalUserId: "user", options: nil) { result, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(result)
            XCTAssertEqual(error?.code, NSError(type: .NoRegistration).code)
            XCTAssertEqual(requestCount, 0)
            self.mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
            // Registration availability is based only on the ID, not on notification permission or the APNs token.
            MMInstallation.modifyAll { installation in
                installation.pushServiceToken = nil
                installation.isPushRegistrationEnabled = false
            }
            inbox.fetchInbox(token: "jwt", externalUserId: "user", options: nil) { result, error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertNil(error)
                XCTAssertNotNil(result)
                inbox.deleteMessages(token: "jwt", externalUserId: "user", messageIds: ["id"]) { error in
                    XCTAssertTrue(Thread.isMainThread)
                    XCTAssertNil(error)
                    completed.fulfill()
                }
            }
        }
        waitForExpectations(timeout: 15, handler: nil)
        XCTAssertEqual(requestCount, 2)
    }

    func testAsyncFetchAndDeleteThrowNoRegistration() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = nil
        let inbox = MobileMessaging.inbox!
        let completed = expectation(description: "Async no registration errors")
        installSessionManagerStub { _, completion in
            XCTFail("No request is allowed before registration is available")
            completion(nil, nil)
        }
        Task {
            let operations: [() async throws -> Void] = [
                { _ = try await inbox.fetchInbox(token: "jwt", externalUserId: "user", options: nil) },
                { _ = try await inbox.fetchInbox(externalUserId: "user", options: nil) },
                { try await inbox.deleteMessages(token: "jwt", externalUserId: "user", messageIds: ["id"]) },
                { try await inbox.deleteMessages(externalUserId: "user", messageIds: ["id"]) }
            ]
            for operation in operations {
                do {
                    try await operation()
                    XCTFail("Expected NoRegistration")
                } catch {
                    let error = error as NSError
                    XCTAssertEqual(error.domain, MMInternalErrorDomain)
                    XCTAssertEqual(error.code, NSError(type: .NoRegistration).code)
                    XCTAssertNil(error.mm_code)
                }
            }
            completed.fulfill()
        }
        waitForExpectations(timeout: 15, handler: nil)
    }

    // MARK: - Cursor pagination
    
    /// Once a registration ID is set, the SDK sends its own requests (e.g. message sync) in the background. Stubs handle only inbox
    /// requests and leave the rest to the default mocks, so those requests never reach a test's assertions.
    static func isInboxRequest(_ requestData: RequestData) -> Bool {
        return requestData is GetInbox || requestData is DeleteInboxMessages
    }

    private func installSessionManagerStub(_ handler: @escaping (RequestData, (JSON?, NSError?) -> Void) -> Void) {
        mobileMessagingInstance.remoteApiProvider = RemoteAPIProvider(sessionManager: SessionManagerStubBase(getDataResponseClosure: { requestData, completion in
            guard InboxServiceTests.isInboxRequest(requestData) else { return false }
            handler(requestData, completion)
            return true
        }))
    }
    
    /// Unlike SessionManagerStubBase, delivers the response on the queue requested by the caller, as the real session manager does.
    private final class QueueHonoringSessionManagerStub: DynamicBaseUrlHTTPSessionManager {
        let handler: (RequestData) -> (JSON?, NSError?)
        init(handler: @escaping (RequestData) -> (JSON?, NSError?)) {
            self.handler = handler
            super.init(baseURL: URL(string: "https://initial-stub.com")!, sessionConfiguration: nil, appGroupId: nil)
        }
        override func getDataResponse(_ r: RequestData, queue: DispatchQueue, completion: @escaping (JSON?, NSError?) -> Void) {
            guard InboxServiceTests.isInboxRequest(r) else {
                queue.async { completion(nil, MMInternalErrorType.UnknownError.foundationError) }
                return
            }
            let (json, error) = handler(r)
            queue.async { completion(json, error) }
        }
    }

    /// Lets a test hold a delete response, then delivers it on the requested queue.
    private final class DeferredDeleteSessionManagerStub: DynamicBaseUrlHTTPSessionManager {
        let onRequest: (RequestData, @escaping (NSError?) -> Void) -> Void

        init(onRequest: @escaping (RequestData, @escaping (NSError?) -> Void) -> Void) {
            self.onRequest = onRequest
            super.init(baseURL: URL(string: "https://initial-stub.com")!, sessionConfiguration: nil, appGroupId: nil)
        }

        override func getDataResponse(_ request: RequestData, queue: DispatchQueue, completion: @escaping (JSON?, NSError?) -> Void) {
            guard request is DeleteInboxMessages else {
                queue.async { completion(nil, MMInternalErrorType.UnknownError.foundationError) }
                return
            }
            DispatchQueue.main.async {
                self.onRequest(request) { error in
                    queue.async { completion(nil, error) }
                }
            }
        }
    }
    
    private func queryItems(of requestData: RequestData) -> [URLQueryItem] {
        let urlRequest = try! requestData.buildURLRequest(baseURL: URL(string: "https://url.com")!)
        return URLComponents(url: urlRequest.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
    }
    
    private func queryValue(_ name: String, of requestData: RequestData) -> String? {
        return queryItems(of: requestData).first(where: { $0.name == name })?.value
    }
    
    private func serverError(_ messageId: String) -> NSError {
        return MMRequestError(messageId: messageId, text: "error text").foundationError
    }
    
    func testThatCursorIsSentWithOtherFilters() {
        startRegisteredSdk()
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        let toDate = Date(timeIntervalSince1970: 1700000000)
        
        installSessionManagerStub { requestData, completion in
            XCTAssertTrue(requestData is GetInbox)
            XCTAssertEqual(self.queryValue("cursor", of: requestData), "c1")
            XCTAssertEqual(self.queryValue("messageTopic", of: requestData), "promo")
            XCTAssertEqual(self.queryValue("limit", of: requestData), "10")
            XCTAssertEqual(self.queryValue("dateTimeTo", of: requestData), "1700000000000")
            completion(JSON.parse("""
            { "messages": [], "countTotal": 30, "countUnread": 3, "nextCursor": "c2" }
            """), nil)
        }
        
        let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: toDate, topic: "promo", limit: 10, cursor: "c1")
        MobileMessaging.inbox?.fetchInbox(token: "givenAccessToken", externalUserId: "user1", options: options, completion: { inbox, error in
            XCTAssertNil(error)
            XCTAssertEqual(inbox?.nextCursor, "c2")
            XCTAssertEqual(inbox?.countTotal, 30)
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatCursorIsNotSentForFirstPage() {
        startRegisteredSdk()
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        
        installSessionManagerStub { requestData, completion in
            XCTAssertNil(self.queryValue("cursor", of: requestData))
            XCTAssertEqual(self.queryValue("messageTopic", of: requestData), "promo")
            completion(JSON.parse("""
            { "messages": [], "countTotal": 30, "countUnread": 3 }
            """), nil)
        }
        
        let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: "promo", limit: nil)
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: options, completion: { inbox, error in
            XCTAssertNil(error)
            XCTAssertNil(inbox?.nextCursor)
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatSequentialPagesFollowNextCursor() {
        startRegisteredSdk()
        weak let pagesFetched = self.expectation(description: "pagesFetched")
        var requestedCursors: [String?] = []
        
        installSessionManagerStub { requestData, completion in
            let cursor = self.queryValue("cursor", of: requestData)
            requestedCursors.append(cursor)
            if cursor == nil {
                completion(JSON.parse("""
                { "messages": [], "countTotal": 4, "countUnread": 1, "nextCursor": "c1" }
                """), nil)
            } else {
                completion(JSON.parse("""
                { "messages": [], "countTotal": 4, "countUnread": 1 }
                """), nil)
            }
        }
        
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: nil, limit: 2), completion: { firstPage, error in
            XCTAssertEqual(firstPage?.nextCursor, "c1")
            let nextOptions = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: nil, limit: 2, cursor: firstPage?.nextCursor)
            MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: nextOptions, completion: { lastPage, error in
                XCTAssertNil(error)
                XCTAssertNil(lastPage?.nextCursor)
                pagesFetched?.fulfill()
            })
        })
        
        waitForExpectations(timeout: 15, handler: nil)
        XCTAssertEqual(requestedCursors, [nil, "c1"])
    }
    
    func testThatInvalidCursorErrorIsPropagatedWithoutRestart() {
        startRegisteredSdk()
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        var requestCount = 0
        
        installSessionManagerStub { requestData, completion in
            requestCount += 1
            completion(nil, self.serverError("INVALID_CURSOR"))
        }
        
        let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: nil, limit: nil, cursor: "broken")
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: options, completion: { inbox, error in
            XCTAssertNil(inbox)
            XCTAssertEqual(error?.mm_code, "INVALID_CURSOR")
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
        XCTAssertEqual(requestCount, 1)
    }
    
    func testThatZeroLimitReturnsCountersOnly() {
        startRegisteredSdk()
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        
        installSessionManagerStub { requestData, completion in
            XCTAssertEqual(self.queryValue("limit", of: requestData), "0")
            completion(JSON.parse("""
            { "messages": [], "countTotal": 12, "countUnread": 4 }
            """), nil)
        }
        
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: nil, limit: 0), completion: { inbox, error in
            XCTAssertEqual(inbox?.messages.count, 0)
            XCTAssertEqual(inbox?.countTotal, 12)
            XCTAssertEqual(inbox?.countUnread, 4)
            XCTAssertNil(inbox?.nextCursor)
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatMultipleTopicsNeverSendCursorAndReturnNoNextCursor() {
        startRegisteredSdk()
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        
        installSessionManagerStub { requestData, completion in
            XCTAssertNil(self.queryValue("cursor", of: requestData))
            completion(JSON.parse("""
            { "messages": [], "countTotal": 12, "countUnread": 4, "nextCursor": "c1" }
            """), nil)
        }
        
        let options = MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topics: ["promo", "news"], limit: 5)
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: options, completion: { inbox, error in
            XCTAssertNil(error)
            XCTAssertNil(inbox?.nextCursor)
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatCursorWithMultipleTopicsIsRejectedLocally() {
        startRegisteredSdk()
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        
        installSessionManagerStub { requestData, completion in
            XCTFail("No request expected")
            completion(nil, nil)
        }
        
        let options = MMInboxFilterOptions(dictRepresentation: ["topics": ["promo"], "cursor": "c1"])
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: options, completion: { inbox, error in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(inbox)
            XCTAssertEqual(error?.domain, MMInternalErrorDomain)
            XCTAssertEqual(error?.code, NSError(type: .UserDataValidationError).code)
            XCTAssertEqual(error?.mm_code, "20013")
            XCTAssertNotNil(error?.mm_message)
            XCTAssertEqual(error?.localizedDescription, error?.mm_message)
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatCursorWithEmptyTopicsIsSent() {
        startRegisteredSdk()
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        
        installSessionManagerStub { requestData, completion in
            XCTAssertEqual(self.queryValue("cursor", of: requestData), "c1")
            completion(JSON.parse("""
            { "messages": [], "countTotal": 12, "countUnread": 4 }
            """), nil)
        }
        
        let options = MMInboxFilterOptions(dictRepresentation: ["topics": [String](), "cursor": "c1"])
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: options, completion: { inbox, error in
            XCTAssertNil(error)
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatTopicAndTopicsFromDictionaryPaginateByTopic() {
        startRegisteredSdk()
        weak let inboxFetched = self.expectation(description: "inboxFetched")

        installSessionManagerStub { requestData, completion in
            XCTAssertEqual(self.queryValue("messageTopic", of: requestData), "sports")
            XCTAssertEqual(self.queryValue("cursor", of: requestData), "c1")
            XCTAssertEqual(self.queryValue("limit", of: requestData), "5")
            completion(JSON.parse("""
            { "messages": [], "countTotal": 12, "countUnread": 4, "nextCursor": "c2" }
            """), nil)
        }

        let options = MMInboxFilterOptions(dictRepresentation: ["topic": "sports", "topics": ["news", "sports"], "limit": 5, "cursor": "c1"])
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: options, completion: { inbox, error in
            XCTAssertNil(error)
            XCTAssertEqual(inbox?.nextCursor, "c2")
            inboxFetched?.fulfill()
        })

        waitForExpectations(timeout: 15, handler: nil)
    }
    
    // MARK: - Delete
    
    func testThatDeleteWithTokenSendsExpectedRequest() {
        startRegisteredSdk()
        weak let deleted = self.expectation(description: "deleted")
        
        installSessionManagerStub { requestData, completion in
            XCTAssertTrue(requestData is DeleteInboxMessages)
            let urlRequest = try! requestData.buildURLRequest(baseURL: URL(string: "https://url.com")!)
            XCTAssertEqual(urlRequest.httpMethod, "DELETE")
            XCTAssertEqual(urlRequest.url?.path, "/mobile/1/user/user1/inbox/messages")
            XCTAssertNil(urlRequest.httpBody)
            XCTAssertEqual(requestData.headers?["Authorization"], "Bearer givenAccessToken")
            XCTAssertNotNil(requestData.headers?["applicationcode"])
            XCTAssertNil(requestData.headers?["pushregistrationid"])
            XCTAssertEqual(self.queryItems(of: requestData).map { $0.name }, ["messageId", "messageId", "messageId"])
            XCTAssertEqual(self.queryItems(of: requestData).map { $0.value }, ["b", "a", "b"])
            completion(nil, nil) // 204 No Content
        }
        
        MobileMessaging.inbox?.deleteMessages(token: "givenAccessToken", externalUserId: "user1", messageIds: ["b", "a", "b"], completion: { error in
            XCTAssertNil(error)
            deleted?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatDeleteWithAppCodeUsesAppAuthorization() {
        startRegisteredSdk()
        weak let deleted = self.expectation(description: "deleted")
        
        installSessionManagerStub { requestData, completion in
            XCTAssertEqual(requestData.headers?["Authorization"], "App \(MMTestConstants.kTestCorrectApplicationCode)")
            XCTAssertEqual(self.queryItems(of: requestData).compactMap { $0.value }, ["a"])
            completion(nil, nil)
        }
        
        MobileMessaging.inbox?.deleteMessages(externalUserId: "user1", messageIds: ["a"], completion: { error in
            XCTAssertNil(error)
            deleted?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatSingleElementDeleteSendsTheIdAsGiven() {
        startRegisteredSdk()
        weak let deletedWithToken = self.expectation(description: "deletedWithToken")
        weak let deletedWithAppCode = self.expectation(description: "deletedWithAppCode")
        var sentIds: [[String]] = []
        
        installSessionManagerStub { requestData, completion in
            sentIds.append(self.queryItems(of: requestData).compactMap { $0.value })
            completion(nil, nil)
        }
        
        MobileMessaging.inbox?.deleteMessages(token: "givenAccessToken", externalUserId: "user1", messageIds: ["legacy+a"], completion: { error in
            XCTAssertNil(error)
            deletedWithToken?.fulfill()
            MobileMessaging.inbox?.deleteMessages(externalUserId: "user1", messageIds: ["m2"], completion: { error in
                XCTAssertNil(error)
                deletedWithAppCode?.fulfill()
            })
        })
        
        waitForExpectations(timeout: 15, handler: nil)
        XCTAssertEqual(sentIds, [["legacy+a"], ["m2"]])
    }
    
    func testThatInvalidDeleteIsRejectedLocally() {
        startRegisteredSdk()
        installSessionManagerStub { requestData, completion in
            XCTFail("No request expected")
            completion(nil, nil)
        }
        
        for messageIds in [[], [""], ["a", "  "]] {
            weak let rejected = self.expectation(description: "rejected \(messageIds)")
            MobileMessaging.inbox?.deleteMessages(token: "givenAccessToken", externalUserId: "user1", messageIds: messageIds, completion: { error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(error?.domain, MMInternalErrorDomain)
                XCTAssertEqual(error?.code, NSError(type: .UserDataValidationError).code)
                XCTAssertEqual(error?.mm_code, "20013")
                XCTAssertNotNil(error?.mm_message)
                XCTAssertEqual(error?.localizedDescription, error?.mm_message, "alert-friendly description should name the actual problem")
                rejected?.fulfill()
            })
        }
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatDeleteServerErrorsArePropagated() {
        startRegisteredSdk()
        let codes = ["UNAUTHORIZED", "FORBIDDEN", "NOT_FOUND", "TOO_MANY_REQUESTS", "INTERNAL_SERVER_ERROR"]
        var responses = codes
        
        installSessionManagerStub { requestData, completion in
            completion(nil, self.serverError(responses.removeFirst()))
        }
        
        for code in codes {
            weak let failed = self.expectation(description: code)
            MobileMessaging.inbox?.deleteMessages(token: "givenAccessToken", externalUserId: "user1", messageIds: ["a"], completion: { error in
                XCTAssertEqual(error?.mm_code, code)
                failed?.fulfill()
            })
            waitForExpectations(timeout: 15, handler: nil)
        }
    }
    
    func testThatDeleteTransportErrorIsPropagated() {
        startRegisteredSdk()
        weak let failed = self.expectation(description: "failed")
        
        installSessionManagerStub { requestData, completion in
            completion(nil, NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))
        }
        
        MobileMessaging.inbox?.deleteMessages(token: "givenAccessToken", externalUserId: "user1", messageIds: ["a"], completion: { error in
            XCTAssertEqual(error?.domain, NSURLErrorDomain)
            XCTAssertEqual(error?.code, NSURLErrorNotConnectedToInternet)
            XCTAssertNil(error?.mm_code)
            failed?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testThatDeleteRetryAfterFailureSendsRequestAgain() {
        startRegisteredSdk()
        weak let retried = self.expectation(description: "retried")
        var sentIds: [[String]] = []
        
        installSessionManagerStub { requestData, completion in
            sentIds.append(self.queryItems(of: requestData).compactMap { $0.value })
            completion(nil, sentIds.count == 1 ? self.serverError("INTERNAL_SERVER_ERROR") : nil)
        }
        
        MobileMessaging.inbox?.deleteMessages(token: "givenAccessToken", externalUserId: "user1", messageIds: ["a", "b"], completion: { error in
            XCTAssertNotNil(error)
            MobileMessaging.inbox?.deleteMessages(token: "givenAccessToken", externalUserId: "user1", messageIds: ["a", "b"], completion: { error in
                XCTAssertNil(error)
                retried?.fulfill()
            })
        })
        
        waitForExpectations(timeout: 15, handler: nil)
        XCTAssertEqual(sentIds, [["a", "b"], ["a", "b"]])
    }
    
    func testAsyncDeleteWaitsForTheTransportResult() {
        startRegisteredSdk()
        let inbox = MobileMessaging.inbox!
        let operations: [() async throws -> Void] = [
            { try await inbox.deleteMessages(token: "jwt", externalUserId: "user", messageIds: ["id"]) },
            { try await inbox.deleteMessages(externalUserId: "user", messageIds: ["id"]) }
        ]
        let forbidden = MMRequestError(messageId: "FORBIDDEN", text: "User mismatch").foundationError(httpStatusCode: 403)
        for operation in operations {
            for expectedError in [nil, forbidden] as [NSError?] {
                let requestStarted = XCTestExpectation(description: "Request started")
                requestStarted.assertForOverFulfill = true
                let completed = expectation(description: "Delete completed")
                completed.assertForOverFulfill = true
                var respond: ((NSError?) -> Void)?
                var finished = false
                mobileMessagingInstance.remoteApiProvider = RemoteAPIProvider(sessionManager: DeferredDeleteSessionManagerStub { _, response in
                    respond = response
                    requestStarted.fulfill()
                })

                Task {
                    do {
                        try await operation()
                        XCTAssertNil(expectedError)
                    } catch {
                        XCTAssertEqual(error as NSError, expectedError)
                        XCTAssertEqual((error as NSError).mm_httpStatusCode, expectedError?.mm_httpStatusCode)
                    }
                    await MainActor.run { finished = true }
                    completed.fulfill()
                }
                wait(for: [requestStarted], timeout: 15)
                XCTAssertFalse(finished, "Delete must await the actual transport result")
                respond?(expectedError)
                waitForExpectations(timeout: 15, handler: nil)
            }
        }
    }

    func testDeleteIsExposedToObjectiveCWithCompletionHandler() {
        startRegisteredSdk()
        let completed = expectation(description: "Objective-C delete completed")
        installSessionManagerStub { requestData, completion in
            XCTAssertEqual(self.queryItems(of: requestData).compactMap { $0.value }, ["a", "b"])
            completion(nil, self.serverError("FORBIDDEN"))
        }
        // Calls the selector the compiler generates for `@objc async throws`, as an Objective-C caller would.
        let selector = NSSelectorFromString("deleteMessagesWithToken:externalUserId:messageIds:completionHandler:")
        let inbox = MobileMessaging.inbox!
        XCTAssertTrue(inbox.responds(to: selector))
        typealias ObjCDelete = @convention(c) (AnyObject, Selector, NSString, NSString, NSArray, @escaping @convention(block) (NSError?) -> Void) -> Void
        let delete = unsafeBitCast(inbox.method(for: selector), to: ObjCDelete.self)
        delete(inbox, selector, "jwt", "user1", ["a", "b"]) { error in
            XCTAssertEqual(error?.mm_code, "FORBIDDEN")
            completed.fulfill()
        }
        waitForExpectations(timeout: 15, handler: nil)
    }

    func testAsyncDeleteValidatesMessageIdsBeforeRegistration() {
        MMTestCase.startWithCorrectApplicationCode()
        mobileMessagingInstance.pushRegistrationId = nil
        let inbox = MobileMessaging.inbox!
        installSessionManagerStub { _, completion in
            XCTFail("Invalid input must not send a request")
            completion(nil, nil)
        }
        let completed = expectation(description: "Async delete validation")
        Task {
            for messageIds in [[], [""], [" \t\n"], ["valid", ""]] as [[String]] {
                let operations: [() async throws -> Void] = [
                    { try await inbox.deleteMessages(token: "jwt", externalUserId: "user", messageIds: messageIds) },
                    { try await inbox.deleteMessages(externalUserId: "user", messageIds: messageIds) }
                ]
                for operation in operations {
                    do {
                        try await operation()
                        XCTFail("Expected local validation error")
                    } catch {
                        let error = error as NSError
                        XCTAssertEqual(error.domain, MMInternalErrorDomain)
                        XCTAssertEqual(error.code, NSError(type: .UserDataValidationError).code)
                        XCTAssertEqual(error.mm_code, "20013")
                        XCTAssertNil(error.mm_httpStatusCode)
                        XCTAssertEqual(error.localizedDescription, messageIds.isEmpty ? "At least one message identifier is required." : "Message identifiers must not be blank.")
                    }
                }
            }
            completed.fulfill()
        }
        waitForExpectations(timeout: 15, handler: nil)
    }

    func testThatEmptyCursorIsNotSent() {
        startRegisteredSdk()
        weak let inboxFetched = self.expectation(description: "inboxFetched")
        
        installSessionManagerStub { requestData, completion in
            XCTAssertFalse(self.queryItems(of: requestData).contains { $0.name == "cursor" })
            completion(JSON.parse("""
            { "messages": [], "countTotal": 0, "countUnread": 0 }
            """), nil)
        }
        
        let options = MMInboxFilterOptions(dictRepresentation: ["cursor": ""])
        MobileMessaging.inbox?.fetchInbox(externalUserId: "user1", options: options, completion: { inbox, error in
            XCTAssertNil(error)
            inboxFetched?.fulfill()
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testBlankCursorsUseFirstPageAcrossFiltersAndAuthorizationModes() {
        startRegisteredSdk()
        let inbox = MobileMessaging.inbox!
        let filters: [[String: Any]] = [[:], ["topic": "Offers"], ["topics": [String]()],
                                        ["topics": ["Offers"]], ["topics": ["Offers", "News"]]]
        // Missing, JSON null, empty and whitespace-only all mean first page.
        let cursors: [String: Any?] = ["missing": nil, "null": NSNull(), "empty": "", "whitespace": " \t\n"]
        installSessionManagerStub { request, completion in
            XCTAssertTrue(request is GetInbox)
            XCTAssertNil(self.queryValue("cursor", of: request))
            completion(JSON.parse("""
            { "messages": [], "countTotal": 21, "countUnread": 4, "nextCursor": "next" }
            """), nil)
        }
        for filter in filters {
            for (name, cursor) in cursors {
                var dictionary = filter
                dictionary["limit"] = 5
                dictionary["cursor"] = cursor
                let options = MMInboxFilterOptions(dictRepresentation: dictionary)
                let clientSide = options.topics?.isEmpty == false
                for useJwt in [false, true] {
                    let fetched = expectation(description: "\(name) cursor, filter \(filter), JWT \(useJwt)")
                    fetched.assertForOverFulfill = true
                    let completion: (MMInbox?, NSError?) -> Void = { result, error in
                        XCTAssertNil(error)
                        XCTAssertNotNil(result)
                        XCTAssertEqual(result?.nextCursor, clientSide ? nil : "next")
                        fetched.fulfill()
                    }
                    if useJwt {
                        inbox.fetchInbox(token: "jwt", externalUserId: "user", options: options, completion: completion)
                    } else {
                        inbox.fetchInbox(externalUserId: "user", options: options, completion: completion)
                    }
                }
            }
        }
        waitForExpectations(timeout: 15, handler: nil)
    }

    func testFetchRejectsBlankTokensAndUserIdsWithoutSendingRequests() {
        startRegisteredSdk()
        let inbox = MobileMessaging.inbox!
        installSessionManagerStub { _, completion in
            XCTFail("Invalid identity must not send a request, including an App-auth fallback")
            completion(nil, nil)
        }
        for blank in ["", " ", "\t\n"] {
            expectLocalValidation("JWT token must not be blank.") { completion in
                inbox.fetchInbox(token: blank, externalUserId: "user", options: nil) { result, error in
                    XCTAssertNil(result)
                    completion(error)
                }
            }
            expectLocalValidation("External user ID must not be blank.") { completion in
                inbox.fetchInbox(token: "jwt", externalUserId: blank, options: nil) { result, error in
                    XCTAssertNil(result)
                    completion(error)
                }
            }
            expectLocalValidation("External user ID must not be blank.") { completion in
                inbox.fetchInbox(externalUserId: blank, options: nil) { result, error in
                    XCTAssertNil(result)
                    completion(error)
                }
            }
        }
        waitForExpectations(timeout: 15, handler: nil)
    }

    func testDeleteRejectsBlankTokensAndUserIdsIncludingSingleMessageWrappers() {
        startRegisteredSdk()
        let inbox = MobileMessaging.inbox!
        installSessionManagerStub { _, completion in
            XCTFail("Invalid identity must not send a request, including an App-auth fallback")
            completion(nil, nil)
        }
        for blank in ["", " ", "\t\n"] {
            expectLocalValidation("JWT token must not be blank.") {
                inbox.deleteMessages(token: blank, externalUserId: "user", messageIds: ["id"], completion: $0)
            }
            expectLocalValidation("External user ID must not be blank.") {
                inbox.deleteMessages(token: "jwt", externalUserId: blank, messageIds: ["id"], completion: $0)
            }
            expectLocalValidation("External user ID must not be blank.") {
                inbox.deleteMessages(externalUserId: blank, messageIds: ["id"], completion: $0)
            }
        }
        waitForExpectations(timeout: 15, handler: nil)
    }

    private func expectLocalValidation(_ message: String, operation: @escaping (@escaping (NSError?) -> Void) -> Void) {
        let completed = expectation(description: message)
        completed.assertForOverFulfill = true
        // The API must deliver local failures on main even when called from a worker queue.
        DispatchQueue.global().async {
            operation { error in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(error?.domain, MMInternalErrorDomain)
                XCTAssertEqual(error?.code, NSError(type: .UserDataValidationError).code)
                XCTAssertEqual(error?.mm_code, "20013")
                XCTAssertEqual(error?.mm_message, message)
                XCTAssertEqual(error?.localizedDescription, message)
                completed.fulfill()
            }
        }
    }

    func testNonblankCursorAndIdentityAreNotTrimmed() {
        startRegisteredSdk()
        let inbox = MobileMessaging.inbox!
        let cursor = "  opaque+/=& cursor  "
        let token = " jwt "
        let user = " user "
        let completed = expectation(description: "fetch and delete completed")
        completed.expectedFulfillmentCount = 2
        installSessionManagerStub { request, completion in
            XCTAssertEqual(request.headers?["Authorization"], "Bearer \(token)")
            let url = try! request.buildURLRequest(baseURL: URL(string: "https://url.com")!).url!
            XCTAssertTrue(URLComponents(url: url, resolvingAgainstBaseURL: false)!.percentEncodedPath.contains("/user/%20user%20/inbox/"))
            if request is GetInbox {
                XCTAssertEqual(self.queryValue("cursor", of: request), cursor)
            } else {
                XCTAssertTrue(request is DeleteInboxMessages)
                XCTAssertEqual(self.queryValue("messageId", of: request), " id ")
            }
            completion(nil, nil)
        }
        inbox.fetchInbox(token: token, externalUserId: user,
                         options: MMInboxFilterOptions(fromDateTime: nil, toDateTime: nil, topic: nil, limit: 5, cursor: cursor)) { _, error in
            XCTAssertNil(error)
            completed.fulfill()
        }
        inbox.deleteMessages(token: token, externalUserId: user, messageIds: [" id "]) { error in
            XCTAssertNil(error)
            completed.fulfill()
        }
        waitForExpectations(timeout: 15, handler: nil)
    }

    func testAsyncFetchAndDeleteThrowLocalIdentityValidationErrors() {
        startRegisteredSdk()
        let inbox = MobileMessaging.inbox!
        let completed = expectation(description: "async validation")
        installSessionManagerStub { _, completion in
            XCTFail("Invalid identity must not send a request")
            completion(nil, nil)
        }
        Task {
            do {
                _ = try await inbox.fetchInbox(token: " ", externalUserId: "user", options: nil)
                XCTFail("Expected token validation error")
            } catch {
                XCTAssertEqual((error as NSError).localizedDescription, "JWT token must not be blank.")
                XCTAssertEqual((error as NSError).mm_code, "20013")
            }
            do {
                try await inbox.deleteMessages(externalUserId: "\t", messageIds: ["id"])
                XCTFail("Expected user validation error")
            } catch {
                XCTAssertEqual((error as NSError).localizedDescription, "External user ID must not be blank.")
                XCTAssertEqual((error as NSError).mm_code, "20013")
            }
            completed.fulfill()
        }
        waitForExpectations(timeout: 15, handler: nil)
    }

    func testThatExternalUserIdIsEscapedInPath() {
        startRegisteredSdk()
        weak let deleted = self.expectation(description: "deleted")
        weak let fetched = self.expectation(description: "fetched")
        
        installSessionManagerStub { requestData, completion in
            let url = try! requestData.buildURLRequest(baseURL: URL(string: "https://url.com")!).url!
            let path = URLComponents(url: url, resolvingAgainstBaseURL: false)!.percentEncodedPath
            XCTAssertTrue(path.hasPrefix("/mobile/1/user/a%20b%2Fc%3Fd%23e%25f%3Bg%3Dh%2Ci%40x.com/inbox/"), path)
            XCTAssertNil(url.fragment)
            completion(JSON.parse("""
            { "messages": [], "countTotal": 0, "countUnread": 0 }
            """), nil)
        }

        // `;` would otherwise end the user ID on the server ("alice;x" is read as "alice").
        let externalUserId = "a b/c?d#e%f;g=h,i@x.com"
        MobileMessaging.inbox?.deleteMessages(externalUserId: externalUserId, messageIds: ["m1"], completion: { error in
            deleted?.fulfill()
            MobileMessaging.inbox?.fetchInbox(externalUserId: externalUserId, options: nil, completion: { inbox, error in
                fetched?.fulfill()
            })
        })
        
        waitForExpectations(timeout: 15, handler: nil)
    }
    
    func testDeleteAsyncVariants() {
        startRegisteredSdk()
        weak let finished = self.expectation(description: "finished")
        var requestCount = 0
        installSessionManagerStub { requestData, completion in
            requestCount += 1
            completion(nil, requestCount == 4 ? self.serverError("UNAUTHORIZED") : nil)
        }
        
        Task {
            do {
                try await MobileMessaging.inbox?.deleteMessages(token: "givenAccessToken", externalUserId: "user1", messageIds: ["a", "b"])
                try await MobileMessaging.inbox?.deleteMessages(externalUserId: "user1", messageIds: ["a"])
                try await MobileMessaging.inbox?.deleteMessages(token: "givenAccessToken", externalUserId: "user1", messageIds: ["a"])
            } catch {
                XCTFail("Unexpected error \(error)")
            }
            do {
                try await MobileMessaging.inbox?.deleteMessages(externalUserId: "user1", messageIds: ["a"])
                XCTFail("Expected error")
            } catch {
                XCTAssertEqual((error as NSError).mm_code, "UNAUTHORIZED")
            }
            finished?.fulfill()
        }
        
        waitForExpectations(timeout: 15, handler: nil)
        XCTAssertEqual(requestCount, 4)
    }
    
}

extension Dictionary where Key == String, Value == Any {
    func extractMessageIdsFromRequestBody() -> [String] {
        let messages = self["messages"] as? [[String: Any]]
        return messages!.compactMap{ $0["messageId"] as? String }
    }
}

/// Delete is async-only. These shims keep the existing delete tests readable; they call the async API and complete on main, as plugin code would.
private extension MMInboxService {
    func deleteMessages(token: String, externalUserId: String, messageIds: [String], completion: @escaping (NSError?) -> Void) {
        complete(completion) { try await self.deleteMessages(token: token, externalUserId: externalUserId, messageIds: messageIds) }
    }
    func deleteMessages(externalUserId: String, messageIds: [String], completion: @escaping (NSError?) -> Void) {
        complete(completion) { try await self.deleteMessages(externalUserId: externalUserId, messageIds: messageIds) }
    }
    private func complete(_ completion: @escaping (NSError?) -> Void, _ operation: @escaping () async throws -> Void) {
        Task { @MainActor in
            do {
                try await operation()
                completion(nil)
            } catch {
                completion(error as NSError)
            }
        }
    }
}
