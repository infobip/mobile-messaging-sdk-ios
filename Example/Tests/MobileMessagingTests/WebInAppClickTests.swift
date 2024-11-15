//
//  WebInAppClickPersistingOperationTests.swift
//  MobileMessaging
//
//  Created by Luka Ilic on 19.09.2024..
//

import XCTest
import CoreData
@testable import MobileMessaging

class WebInAppClickTests: MMTestCase {
    func testSuccessfulWebInAppClickPersisting() {
        MMTestCase.startWithCorrectApplicationCode()

        weak var expectation = self.expectation(description: "Click persisted")
        
        let click = MMWebInAppClick(clickUrl: MMTestConstants.kTestWebInAppClickUrl, buttonIdx: MMTestConstants.kTestWebInAppButtonIdx)
        let context = self.storage.mainThreadManagedObjectContext!
        
        let operation = WebInAppClickPersistingOperation(
            webInAppClick: click,
            pushRegId: MMTestConstants.kTestCorrectInternalID,
            context: context
        ) { error in
            XCTAssertNil(error)
            expectation?.fulfill()
        }
        
        operation.execute()
        
        waitForExpectations(timeout: 20) { _ in
            let clicks = WebInAppClickObject.MM_findAllInContext(context)!
            XCTAssertEqual(clicks.count, 1)
            XCTAssertEqual(clicks.first?.clickUrl, MMTestConstants.kTestWebInAppClickUrl)
            XCTAssertEqual(clicks.first?.buttonIdx, MMTestConstants.kTestWebInAppButtonIdx)
            XCTAssertEqual(clicks.first?.attempt, 0)
        }
    }
    
    func testDuplicateClickUrlNotPersisted() {
        MMTestCase.startWithCorrectApplicationCode()
        
        weak var expectation = self.expectation(description: "Operations completed")
        
        let context = self.storage.mainThreadManagedObjectContext!
        let click = MMWebInAppClick(clickUrl: MMTestConstants.kTestWebInAppClickUrl, buttonIdx: MMTestConstants.kTestWebInAppButtonIdx)
        
        // First operation
        let operation1 = WebInAppClickPersistingOperation(
            webInAppClick: click,
            pushRegId: MMTestConstants.kTestCorrectInternalID,
            context: context
        ) { _ in
            // Second operation - duplicate
            let operation2 = WebInAppClickPersistingOperation(
                webInAppClick: click,
                pushRegId: MMTestConstants.kTestCorrectInternalID,
                context: context
            ) { _ in
                expectation?.fulfill()
            }
            operation2.execute()
        }
        
        operation1.execute()
        
        waitForExpectations(timeout: 20) { _ in
            let clicks = WebInAppClickObject.MM_findAllInContext(context)!
            XCTAssertEqual(clicks.count, 1)
        }
    }
    
    func testPersistingOperationCancelledHandledCorrectly() {
        MMTestCase.startWithCorrectApplicationCode()

        weak var expectation = self.expectation(description: "Operation cancelled")
        
        let context = self.storage.mainThreadManagedObjectContext!
        let click = MMWebInAppClick(clickUrl: MMTestConstants.kTestWebInAppClickUrl, buttonIdx: MMTestConstants.kTestWebInAppButtonIdx)
        
        let operation = WebInAppClickPersistingOperation(
            webInAppClick: click,
            pushRegId: MMTestConstants.kTestCorrectInternalID,
            context: context
        ) { _ in
            expectation?.fulfill()
        }
        
        operation.cancel()
        operation.execute()
        
        waitForExpectations(timeout: 20) { _ in
            let clicks = WebInAppClickObject.MM_findAllInContext(context)!
            XCTAssertEqual(clicks.count, 0, "Cancelled operation should not persist")
        }
    }
    
    func testWebInAppClickServiceAndReportingSuccess() {
        MMTestCase.startWithCorrectApplicationCode()
        
        weak var expectation = self.expectation(description: "expectation1")
        weak var expectation2 = self.expectation(description: "expectation2")
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        
        let testClickUrl = MMTestConstants.kTestWebInAppClickUrl
        let testButtonIdx = MMTestConstants.kTestWebInAppButtonIdx
        
        let apiStub = RemoteAPIProviderStub()
        apiStub.sendWebInAppClickReportClosure = { url, appCode, pushRegId, buttonIdx in
            XCTAssertEqual(url.absoluteString, testClickUrl)
            XCTAssertEqual(buttonIdx, testButtonIdx)
            XCTAssertEqual(pushRegId, MMTestConstants.kTestCorrectInternalID)
            expectation2?.fulfill()
            return .Success(EmptyResponse())
        }
        
        mobileMessagingInstance.remoteApiProvider = apiStub
        mobileMessagingInstance.webInAppClickService = WebInAppClickService(mmContext: mobileMessagingInstance)
        
        mobileMessagingInstance.webInAppClickService?.submitWebInAppClick(
            clickUrl: testClickUrl,
            buttonIdx: testButtonIdx
        ) { _ in
            expectation?.fulfill()
        }
        
        waitForExpectations(timeout: 15) { _ in
            let ctx = self.storage.mainThreadManagedObjectContext!
            let clicks = WebInAppClickObject.MM_findAllInContext(ctx)!
            XCTAssertTrue(clicks.isEmpty, "Clicks should be removed after successful report")
        }
    }
    
    func testWebInAppClickServiceAndReportingFailure() {
        MMTestCase.startWithCorrectApplicationCode()
        
        weak var expectation = self.expectation(description: "case is finished")
        weak var expectation2 = self.expectation(description: "request attempted")
        
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        
        let testClickUrl = MMTestConstants.kTestWebInAppClickUrl
        let testButtonIdx = MMTestConstants.kTestWebInAppButtonIdx
        
        let apiStub = RemoteAPIProviderStub()
        apiStub.sendWebInAppClickReportClosure = { url, appCode, pushRegId, buttonIdx in
            expectation2?.fulfill()
            return .Failure(nil)
        }
        mobileMessagingInstance.remoteApiProvider = apiStub
        mobileMessagingInstance.webInAppClickService = WebInAppClickService(mmContext: mobileMessagingInstance)
        
        mobileMessagingInstance.webInAppClickService?.submitWebInAppClick(
            clickUrl: testClickUrl,
            buttonIdx: testButtonIdx
        ) { _ in
            expectation?.fulfill()
        }
        
        waitForExpectations(timeout: 20) { _ in
            let ctx = self.storage.mainThreadManagedObjectContext!
            let clicks = WebInAppClickObject.MM_findAllInContext(ctx)!
            XCTAssertEqual(clicks.count, 1, "Click should be persisted after failed report")
            XCTAssertEqual(clicks.first?.clickUrl, testClickUrl)
            XCTAssertEqual(clicks.first?.buttonIdx, testButtonIdx)
            XCTAssertEqual(clicks.first?.attempt, 1)
        }
    }
    
    func testWebInAppReportRetriesOnAppWillEnterForeground() {
        MMTestCase.startWithCorrectApplicationCode()
        
        weak var expectation = self.expectation(description: "retries completed")
        mobileMessagingInstance.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        
        let testClickUrl = MMTestConstants.kTestWebInAppClickUrl
        let testButtonIdx = MMTestConstants.kTestWebInAppButtonIdx
        
        let apiStub = RemoteAPIProviderStub()
        var attempts = 0
        apiStub.sendWebInAppClickReportClosure = { url, appCode, pushRegId, buttonIdx in
            attempts += 1
            return .Failure(nil)
        }
        
        mobileMessagingInstance.remoteApiProvider = apiStub
        mobileMessagingInstance.webInAppClickService = WebInAppClickService(mmContext: mobileMessagingInstance)
        
        mobileMessagingInstance.webInAppClickService?.submitWebInAppClick(
            clickUrl: testClickUrl,
            buttonIdx: testButtonIdx
        ) { _ in
            self.triggerRetries {
                expectation?.fulfill()
            }
        }
        
        waitForExpectations(timeout: 20) { _ in
            XCTAssertEqual(attempts, 3, "Should attempt 3 times")
            let ctx = self.storage.mainThreadManagedObjectContext!
            let clicks = WebInAppClickObject.MM_findAllInContext(ctx)!
            XCTAssertEqual(clicks.count, 0, "Click should be removed after max retries")
        }
    }
    
    private func triggerRetries(completion: @escaping () -> Void) {
        mobileMessagingInstance.webInAppClickService?.appWillEnterForeground {
            self.mobileMessagingInstance.webInAppClickService?.appWillEnterForeground {
                self.mobileMessagingInstance.webInAppClickService?.appWillEnterForeground {
                    completion()
                }
            }
        }
    }
}
