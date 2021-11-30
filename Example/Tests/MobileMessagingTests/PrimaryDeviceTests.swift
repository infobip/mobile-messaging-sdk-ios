//
//  File.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 26/06/2018.
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
	
	func testPutSync() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "sync completed")
		mobileMessagingInstance.pushRegistrationId = "123"

		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		let installation = MobileMessaging.getInstallation()!
		XCTAssertFalse(installation.isPrimaryDevice)
		installation.isPrimaryDevice = true
		MobileMessaging.saveInstallation(installation) { (error) in
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20, handler: { _ in
			let installation = MobileMessaging.getInstallation()!
			XCTAssertNil(MMInstallation.delta?["isPrimaryDevice"])
			XCTAssertTrue(installation.isPrimaryDevice)
		})
	}
	
	func testGetSync() {
        MMTestCase.startWithCorrectApplicationCode()
        
		weak var expectation = self.expectation(description: "sync completed")
		mobileMessagingInstance.pushRegistrationId = "123"
		let remoteApiProvider = RemoteAPIProviderStub()
		remoteApiProvider.patchInstanceClosure = { _, _, _, _ -> UpdateInstanceDataResult in
			return UpdateInstanceDataResult.Success(EmptyResponse())
		}
		mobileMessagingInstance.remoteApiProvider = remoteApiProvider

		MobileMessaging.fetchInstallation { (installation, error) in
			XCTAssertFalse(installation!.isPrimaryDevice)
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20, handler: { _ in
			let installation = MobileMessaging.getInstallation()!
			XCTAssertNil(MMInstallation.delta?["isPrimaryDevice"])
			XCTAssertFalse(installation.isPrimaryDevice)
		})
	}
}
