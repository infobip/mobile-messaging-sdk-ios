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
		XCTAssertTrue(MobileMessaging.isPrimaryDevice)
		MobileMessaging.isPrimaryDevice = false
		XCTAssertFalse(MobileMessaging.isPrimaryDevice)
		let ctx = self.mobileMessagingInstance.currentInstallation.coreDataProvider.context
		ctx.performAndWait {
			let installation = InstallationManagedObject.MM_findFirstInContext(ctx)!
			XCTAssertTrue(installation.dirtyAttributesSet.contains(AttributesSet.isPrimaryDevice))
			XCTAssertFalse(installation.isPrimaryDevice)
		}
	}
	
	func testPutSync() {
		weak var expectation = self.expectation(description: "sync completed")
		mobileMessagingInstance.currentUser.pushRegistrationId = "123"
		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(mmContext: mobileMessagingInstance, performRequestCompanionBlock: { (request) in
			
		}, completionCompanionBlock: { (request) in
			
		}, responseMock: { (request) -> JSON? in
			
			switch request {
			case (is PutInstanceRequest):
				return JSON("")
			case (is GetInstanceRequest):
				return JSON(["primary" : true])
			default:
				return nil
			}
		})
		
		XCTAssertTrue(MobileMessaging.isPrimaryDevice)
		
		MobileMessaging.setAsPrimaryDevice(false) { (error) in
			expectation?.fulfill()
		}
		
		waitForExpectations(timeout: 20, handler: { _ in
			let ctx = self.mobileMessagingInstance.currentInstallation.coreDataProvider.context
			ctx.performAndWait {
				let installation = InstallationManagedObject.MM_findFirstInContext(ctx)!
				XCTAssertFalse(installation.dirtyAttributesSet.contains(AttributesSet.isPrimaryDevice))
				XCTAssertFalse(installation.isPrimaryDevice)
			}
		})
	}
	
	func testGetSync() {
		weak var expectation = self.expectation(description: "sync completed")
		mobileMessagingInstance.currentUser.pushRegistrationId = "123"
		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(mmContext: mobileMessagingInstance, performRequestCompanionBlock: { (request) in
			
		}, completionCompanionBlock: { (request) in
			
		}, responseMock: { (request) -> JSON? in
			
			switch request {
			case (is PutInstanceRequest):
				return JSON("")
			case (is GetInstanceRequest):
				return JSON(["primary" : false])
			default:
				return nil
			}
		})
		
		mobileMessagingInstance.currentInstallation.syncPrimaryFlagWithServer { (error) in
			expectation?.fulfill()
		}
		
		waitForExpectations(timeout: 20, handler: { _ in
			let ctx = self.mobileMessagingInstance.currentInstallation.coreDataProvider.context
			ctx.performAndWait {
				let installation = InstallationManagedObject.MM_findFirstInContext(ctx)!
				XCTAssertFalse(installation.dirtyAttributesSet.contains(AttributesSet.isPrimaryDevice))
				XCTAssertFalse(installation.isPrimaryDevice)
			}
		})
	}
}
