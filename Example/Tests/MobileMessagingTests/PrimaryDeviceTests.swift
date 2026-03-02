// 
//  Example/Tests/MobileMessagingTests/PrimaryDeviceTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
@testable import MobileMessaging

class PrimaryDeviceTests: MMTestCase {
	func testDataPersisting() {
        MMTestCase.startWithCorrectApplicationCode()
        
		XCTAssertFalse(MobileMessaging.getInstallation()!.isPrimaryDevice)
		MobileMessaging.sharedInstance!.isPrimaryDevice = true
        
        waitForExpectations(timeout: 20, handler: { _ in
            XCTAssertTrue(MobileMessaging.getInstallation()!.isPrimaryDevice)

            let installation = MobileMessaging.getInstallation()!
            XCTAssertNotNil(MMInstallation.delta!["isPrimaryDevice"])
            XCTAssertTrue(installation.isPrimaryDevice)
        })
	}
	
	func testPutSync() async throws {
        MMTestCase.startWithCorrectApplicationCode()

		mobileMessagingInstance.pushRegistrationId = "123"

		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		let installation = MobileMessaging.getInstallation()!
		XCTAssertFalse(installation.isPrimaryDevice)
		installation.isPrimaryDevice = true
		try await MobileMessaging.saveInstallation(installation)
		let saved = MobileMessaging.getInstallation()!
		XCTAssertNil(MMInstallation.delta?["isPrimaryDevice"])
		XCTAssertTrue(saved.isPrimaryDevice)
	}

	func testGetSync() async throws {
        MMTestCase.startWithCorrectApplicationCode()

		mobileMessagingInstance.pushRegistrationId = "123"
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		let installation = try await MobileMessaging.fetchInstallation()
		XCTAssertFalse(installation.isPrimaryDevice)
		let saved = MobileMessaging.getInstallation()!
		XCTAssertNil(MMInstallation.delta?["isPrimaryDevice"])
		XCTAssertFalse(saved.isPrimaryDevice)
	}
}
