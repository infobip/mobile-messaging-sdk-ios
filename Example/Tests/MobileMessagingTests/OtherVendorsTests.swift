//
//  OtherVendorsTests.swift
//  MobileMessagingExample_Tests
//
//  Created by Andrey Kadochnikov on 28.03.2022.
//

import Foundation
import XCTest
@testable import MobileMessaging

class OtherVendorsTests: MMTestCase {

    func testShouldNotRegisterDuringStart() {
        let mm = MobileMessaging.withApplicationCode("code", notificationType: MMUserNotificationType(options: []) , backendBaseURL: "http://url.com")!.withoutRegisteringForRemoteNotifications()
        
        mm.setupApiSessionManagerStubbed()
        let appMock = DefaultApplicationStub()
        appMock.registerForRemoteNotificationsStub = {
            XCTFail("should not be called because MM SDK built withoutRegisteringForRemoteNotifications")
        }
        MobileMessaging.application = appMock
        mm.doStart()
        waitForExpectations(timeout: 5, handler: { _ in })
    }
    
    func testShouldRegisterDuringStart() {
        weak var expectation = self.expectation(description: "registerForRemoteNotifications called")
        let mm = MobileMessaging.withApplicationCode("code", notificationType: MMUserNotificationType(options: []) , backendBaseURL: "http://url.com")!
        
        mm.setupApiSessionManagerStubbed()
        let appMock = DefaultApplicationStub()
        appMock.registerForRemoteNotificationsStub = {
            expectation?.fulfill()
        }
        MobileMessaging.application = appMock
        mm.doStart()
        waitForExpectations(timeout: 5, handler: { _ in })
    }
    
    func testShouldNotSetNotificationCenterDelegateAfterStart() {
        let mm = MobileMessaging.withApplicationCode("code", notificationType: MMUserNotificationType(options: []) , backendBaseURL: "http://url.com")!.withoutOverridingNotificationCenterDelegate()

        mm.setupApiSessionManagerStubbed()
        MobileMessaging.application = ActiveApplicationStub()
        mm.doStart()
        
        waitForExpectations(timeout: 5, handler: { _ in
            XCTAssertNil(UNUserNotificationCenter.current().delegate)
        })
    }
    
    func testShouldSetNotificationCenterDelegateAfterStart() {
        let mm = MobileMessaging.withApplicationCode("code", notificationType: MMUserNotificationType(options: []) , backendBaseURL: "http://url.com")!

        mm.setupApiSessionManagerStubbed()
        MobileMessaging.application = ActiveApplicationStub()
        mm.doStart()
        
        waitForExpectations(timeout: 5, handler: { _ in
            XCTAssertNotNil(UNUserNotificationCenter.current().delegate)
        })
    }
    
    func testShouldNotUnregisterOnFailedDepersonalization() {
        weak var expectation = self.expectation(description: "depersonalization finished")
        let mm = MobileMessaging.withApplicationCode("code", notificationType: MMUserNotificationType(options: []) , backendBaseURL: "http://url.com")!.withoutUnregisteringForRemoteNotifications()

        let appMock = DefaultApplicationStub()
        appMock.unregisterForRemoteNotificationsStub = {
            XCTFail("should not be called because MM SDK built withoutUnregisteringForRemoteNotifications")
        }
        MobileMessaging.application = appMock
        mm.doStart()
        mm.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        MobileMessaging.sharedInstance?.remoteApiProvider = failedDepersonalizeApiMock
        MobileMessaging.depersonalize() { s, e in
            XCTAssertEqual(MMSuccessPending.pending, s)
            XCTAssertNotNil(e)
            expectation?.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: { _ in
            
        })
    }
    
    func testShouldUnregisterOnFailedDepersonalization() {
        weak var unregisterExpectation = self.expectation(description: "unregister called")
        unregisterExpectation!.assertForOverFulfill = false
        weak var depersonalizeExpectation = self.expectation(description: "depersonalization finished")
        let mm = MobileMessaging.withApplicationCode("code", notificationType: MMUserNotificationType(options: []) , backendBaseURL: "http://url.com")!

        let appMock = DefaultApplicationStub()
        appMock.unregisterForRemoteNotificationsStub = {
            unregisterExpectation?.fulfill()
        }
        MobileMessaging.application = appMock
        mm.doStart()
        mm.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        MobileMessaging.sharedInstance?.remoteApiProvider = failedDepersonalizeApiMock
        MobileMessaging.depersonalize() { s, e in
            XCTAssertEqual(MMSuccessPending.pending, s)
            XCTAssertNotNil(e)
            depersonalizeExpectation?.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: { _ in
            
        })
    }
}
