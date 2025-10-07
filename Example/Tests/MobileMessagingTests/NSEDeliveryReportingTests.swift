// 
//  Example/Tests/MobileMessagingTests/NSEDeliveryReportingTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
@testable import MobileMessaging

// MARK: - NSE Delivery Reporting Tests

class NSEDeliveryReportingTests: XCTestCase {
	
	override func setUp() {
		super.setUp()
		MobileMessagingNotificationServiceExtension.sharedInstance = nil
	}
	
	override func tearDown() {
		MobileMessagingNotificationServiceExtension.sharedInstance = nil
		super.tearDown()
	}
	
	func testDeliveryReportRequest_ConstructorWithPushRegId() {
		let applicationCode = "test-app-code"
		let pushRegId = "test-push-reg-id"
		let messageIds = ["msg1", "msg2"]
		
		let request = DeliveryReportRequest(
			applicationCode: applicationCode,
			pushRegistrationId: pushRegId,
			body: [Consts.DeliveryReport.dlrMessageIds: messageIds]
		)
		
		XCTAssertEqual(request.pushRegistrationId, pushRegId)
		XCTAssertEqual(request.applicationCode, applicationCode)
		
		let bodyMessageIds = request.body?[Consts.DeliveryReport.dlrMessageIds] as? [String]
		XCTAssertEqual(bodyMessageIds, messageIds)
	}
	
	func testDeliveryReportRequest_ConstructorWithoutPushRegId() {
		let applicationCode = "test-app-code"
		let messageIds = ["msg1", "msg2"]
		
		let request = DeliveryReportRequest(
			applicationCode: applicationCode,
			body: [Consts.DeliveryReport.dlrMessageIds: messageIds]
		)
		
		XCTAssertNil(request.pushRegistrationId)
		XCTAssertEqual(request.applicationCode, applicationCode)
	}
	
	func testRequestHeaders_ContainsPushRegistrationId() {
		let request = DeliveryReportRequest(
			applicationCode: "test-app",
			pushRegistrationId: "test-push-reg-id",
			body: [Consts.DeliveryReport.dlrMessageIds: ["msg1"]]
		)
		
		let headers = request.headers
		XCTAssertEqual(headers?[MMConsts.APIHeaders.pushRegistrationId], "test-push-reg-id")
		XCTAssertEqual(headers?[MMConsts.APIHeaders.applicationcode], calculateAppCodeHash("test-app"))
	}
	
	func testRequestHeaders_IncludeInstallationId() {
        let testAppGroupId = Bundle.mainAppBundle.appGroupId
		let expectedInstallationId = "nse-installation-id"
		
		if let sharedDefaults = UserDefaults(suiteName: testAppGroupId) {
			sharedDefaults.set(expectedInstallationId, forKey: Consts.UserDefaultsKeys.universalInstallationId)
			
			let request = DeliveryReportRequest(
				applicationCode: "test-app",
				pushRegistrationId: "test-push-reg-id",
				body: [Consts.DeliveryReport.dlrMessageIds: ["msg1"]]
			)
			
			let headers = request.headers
            XCTAssertEqual(headers?[MMConsts.APIHeaders.installationId], expectedInstallationId)
			
			sharedDefaults.removeObject(forKey: Consts.UserDefaultsKeys.universalInstallationId)
		} else {
			XCTAssert(true, "Skipping - no App Group configured")
		}
	}
}
