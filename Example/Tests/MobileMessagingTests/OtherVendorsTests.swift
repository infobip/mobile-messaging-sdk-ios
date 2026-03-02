// 
//  Example/Tests/MobileMessagingTests/OtherVendorsTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
        weak let expectation = self.expectation(description: "registerForRemoteNotifications called")
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
    
    func testShouldNotUnregisterOnFailedDepersonalization() async throws {
        let mm = MobileMessaging.withApplicationCode("code", notificationType: MMUserNotificationType(options: []) , backendBaseURL: "http://url.com")!.withoutUnregisteringForRemoteNotifications()

        let appMock = DefaultApplicationStub()
        appMock.unregisterForRemoteNotificationsStub = {
            XCTFail("should not be called because MM SDK built withoutUnregisteringForRemoteNotifications")
        }
        MobileMessaging.application = appMock
        mm.doStart()
        mm.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        MobileMessaging.sharedInstance?.remoteApiProvider = failedDepersonalizeApiMock
        do {
            _ = try await MobileMessaging.depersonalize()
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(MMSuccessPending.pending, mm.internalData().currentDepersonalizationStatus)
        }
    }

    func testShouldUnregisterOnFailedDepersonalization() async throws {
        weak let unregisterExpectation = self.expectation(description: "unregister called")
        unregisterExpectation!.assertForOverFulfill = false
        let mm = MobileMessaging.withApplicationCode("code", notificationType: MMUserNotificationType(options: []) , backendBaseURL: "http://url.com")!

        let appMock = DefaultApplicationStub()
        appMock.unregisterForRemoteNotificationsStub = {
            unregisterExpectation?.fulfill()
        }
        MobileMessaging.application = appMock
        mm.doStart()
        mm.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
        MobileMessaging.sharedInstance?.remoteApiProvider = failedDepersonalizeApiMock
        do {
            _ = try await MobileMessaging.depersonalize()
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(MMSuccessPending.pending, mm.internalData().currentDepersonalizationStatus)
        }
        await fulfillment(of: [unregisterExpectation!], timeout: 5)
    }
}
