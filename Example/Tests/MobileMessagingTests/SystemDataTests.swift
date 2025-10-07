// 
//  Example/Tests/MobileMessagingTests/SystemDataTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
@testable import MobileMessaging

class SystemDataTests: MMTestCase {
	
	func testThatNotificationsSettingsIsBeingSyncedAfterChanged() {
        MMTestCase.startWithCorrectApplicationCode()
        
		//Preparations
		weak var expectation = self.expectation(description: "registration sent")
		var sentSettings = [Bool]()
		let remoteProviderMock = RemoteAPIProviderStub()
		remoteProviderMock.patchInstanceClosure = { _, _, _, requestBody in
			sentSettings.append(requestBody["notificationsEnabled"] as! Bool)
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}
		mobileMessagingInstance.remoteApiProvider = remoteProviderMock

		//requirements
		mobileMessagingInstance.pushRegistrationId = "stub"
		mobileMessagingInstance.systemDataHash = 0
		
		MobileMessaging.application = NotificationsEnabledMock() //<<<

		// system data sends notificationsEnabled: true (initial sync because systemDataHash == 0) + 1
        self.mobileMessagingInstance.installationService.syncSystemDataWithServer(userInitiated: true, completion: { error in

			MobileMessaging.application = NotificationsDisabledMock() //<<<
			// system data sends notificationsEnabled: false  (notification settings changed but the timeout is not expired)
			self.mobileMessagingInstance.installationService.syncSystemDataWithServer(userInitiated: true, completion: { error in

				timeTravel(to: Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 60*60), block: {

					// system data sends notificationsEnabled: false  (now, another request is expected because timeout has expired) + 1
					self.mobileMessagingInstance.installationService.syncSystemDataWithServer(userInitiated: true, completion: { error in
						expectation?.fulfill()
					})
				})
			})
		})

		self.waitForExpectations(timeout: 6000) { error in
			XCTAssertEqual(sentSettings.count, 2)
			XCTAssertTrue(sentSettings.contains(true))
			XCTAssertTrue(sentSettings.contains(false))
		}
	}

	func testThatSystemDataRespectsPrivacySettings() {
		do {
			MobileMessaging.privacySettings.systemInfoSendingDisabled = true
			let body = MobileMessaging.userAgent.systemData.requestPayload
			XCTAssertNil(body[Consts.SystemDataKeys.appVer])
			XCTAssertNil(body[Consts.SystemDataKeys.deviceModel])
			XCTAssertNil(body[Consts.SystemDataKeys.language])
			XCTAssertNotNil(body[Consts.SystemDataKeys.sdkVersion])
			XCTAssertNotNil(body[Consts.SystemDataKeys.notificationsEnabled])
			XCTAssertNil(body[Consts.SystemDataKeys.deviceSecure])
		}

		do {
			MobileMessaging.privacySettings.systemInfoSendingDisabled = false
			let body = MobileMessaging.userAgent.systemData.requestPayload
			XCTAssertNotNil(body[Consts.SystemDataKeys.deviceManufacturer])
			XCTAssertNotNil(body[Consts.SystemDataKeys.osVer])
			XCTAssertNotNil(body[Consts.SystemDataKeys.appVer])
			XCTAssertNotNil(body[Consts.SystemDataKeys.deviceManufacturer])
			XCTAssertNotNil(body[Consts.SystemDataKeys.deviceModel])
			XCTAssertNotNil(body[Consts.SystemDataKeys.osVer])
			XCTAssertNotNil(body[Consts.SystemDataKeys.language])
			XCTAssertNotNil(body[Consts.SystemDataKeys.sdkVersion])
			XCTAssertNotNil(body[Consts.SystemDataKeys.notificationsEnabled])
			XCTAssertNotNil(body[Consts.SystemDataKeys.deviceSecure])
		}
	}
}
