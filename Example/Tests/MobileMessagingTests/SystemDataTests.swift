//
//  SystemDataTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 29/08/16.
//

import XCTest
@testable import MobileMessaging

class UserAgentStub: MMUserAgent {
	override var libraryVersion: String {
		return "1.0.0"
	}
	override var osName: String {
		return "mobile OS"
	}
	override var osVersion: String {
		return "1.0"
	}
	override var deviceName: String {
		return "iPhone Galaxy"
	}
	override var hostingAppName: String {
		return "WheatherApp"
	}
	override var hostingAppVersion: String {
		return "1.0"
	}
	override var deviceManufacturer: String {
		return "GoogleApple"
	}
}

class GeoAvailableUserAgentStub: UserAgentStub {
	override var isGeoAvailable: Bool {
		return true
	}
}

class GeoNotAvailableUserAgentStub: UserAgentStub {
	override var isGeoAvailable: Bool {
		return false
	}
}

class SystemDataTests: MMTestCase {

    func testSystemDataUpdates() {
		weak var requestsCompleted = expectationWithDescription("requestsCompleted")
		let ctx = self.storage.mainThreadManagedObjectContext!
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		var initialSystemDataHash: Int64 = 0
		MobileMessaging.userAgent = GeoNotAvailableUserAgentStub()
		
		if let installation = InstallationManagedObject.MM_findFirstInContext(context: ctx) {
			initialSystemDataHash = installation.systemDataHash
		}
		
		var updatedSystemDataHash: Int64!
		MobileMessaging.userAgent = GeoAvailableUserAgentStub()
		MobileMessaging.currentInstallation?.syncWithServer({ (error) in
			
			ctx.reset()
			if let installation = InstallationManagedObject.MM_findFirstInContext(context: ctx) {
				updatedSystemDataHash = installation.systemDataHash
			}
			
			MobileMessaging.userAgent = GeoNotAvailableUserAgentStub()
			
			MobileMessaging.currentInstallation?.syncWithServer({ (error) in
				requestsCompleted?.fulfill()
			})
		})
		
		self.waitForExpectationsWithTimeout(60) { err in
			
			ctx.reset()
			if let installation = InstallationManagedObject.MM_findFirstInContext(context: ctx) {
				XCTAssertEqual(initialSystemDataHash, 0)
				XCTAssertNotEqual(initialSystemDataHash, updatedSystemDataHash)
				XCTAssertNotEqual(installation.systemDataHash, initialSystemDataHash)
				XCTAssertNotEqual(installation.systemDataHash, updatedSystemDataHash)
			}
		}
    }
}
