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
		XCTAssertFalse(MobileMessaging.currentInstallation!.isPrimaryDevice)
		MobileMessaging.currentInstallation!.isPrimaryDevice = true
		MobileMessaging.currentInstallation!.persist()
		XCTAssertTrue(MobileMessaging.currentInstallation!.isPrimaryDevice)
		let ctx = self.mobileMessagingInstance.currentInstallation.coreDataProvider.context
		ctx.performAndWait {
			let installation = InstallationManagedObject.MM_findFirstInContext(ctx)!
			XCTAssertTrue(installation.dirtyAttsSet.contains(Attributes.isPrimaryDevice))
			XCTAssertTrue(installation.isPrimary)
		}
	}
	
	func testPutSync() {
		weak var expectation = self.expectation(description: "sync completed")
		mobileMessagingInstance.currentInstallation.pushRegistrationId = "123"
		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(performRequestCompanionBlock: { (request) in
			
		}, completionCompanionBlock: { (request) in
			
		}, responseMock: { (request) -> JSON? in
			
			switch request {
			case (is PatchInstance):
				return JSON("")
			default:
				return nil
			}
		})

		let installation = MobileMessaging.installation!
		XCTAssertFalse(installation.isPrimaryDevice)
		installation.isPrimaryDevice = true
		MobileMessaging.saveInstallation(installation) { (error) in
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20, handler: { _ in
			let ctx = self.mobileMessagingInstance.currentInstallation.coreDataProvider.context
			ctx.performAndWait {
				let installation = InstallationManagedObject.MM_findFirstInContext(ctx)!
				XCTAssertFalse(installation.dirtyAttsSet.contains(Attributes.isPrimaryDevice))
				XCTAssertTrue(installation.isPrimary)
			}
		})
	}
	
	func testGetSync() {
		weak var expectation = self.expectation(description: "sync completed")
		mobileMessagingInstance.currentInstallation.pushRegistrationId = "123"
		mobileMessagingInstance.remoteApiProvider.registrationQueue = MMRemoteAPIMock(performRequestCompanionBlock: { (request) in
			
		}, completionCompanionBlock: { (request) in
			
		}, responseMock: { (request) -> JSON? in
			switch request {
			case (is PatchInstance):
				return JSON("")
			default:
				return nil
			}
		})

		MobileMessaging.fetchInstallation { (installation, error) in
			XCTAssertFalse(installation!.isPrimaryDevice)
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20, handler: { _ in
			let ctx = self.mobileMessagingInstance.currentInstallation.coreDataProvider.context
			ctx.performAndWait {
				let installation = InstallationManagedObject.MM_findFirstInContext(ctx)!
				XCTAssertFalse(installation.dirtyAttsSet.contains(Attributes.isPrimaryDevice))
				XCTAssertFalse(installation.isPrimary)
			}
		})
	}
}
