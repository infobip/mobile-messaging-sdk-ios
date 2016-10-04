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
		let requestsCompleted = expectation(description: "requestsCompleted")
		let ctx = self.storage.mainThreadManagedObjectContext!
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		var initialSystemDataHash: Int!
		MobileMessaging.userAgent = GeoNotAvailableUserAgentStub()
		
		if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
			initialSystemDataHash = installation.systemDataHash.integerValue
		}
		
		var updatedSystemDataHash: Int!
		MobileMessaging.userAgent = GeoAvailableUserAgentStub()
		MobileMessaging.currentInstallation?.syncWithServer(completion: { (error) in
			
			ctx.reset()
			if let installation = InstallationManagedObject.MM_findFirstInContext(context: ctx) {
				updatedSystemDataHash = installation.systemDataHash.integerValue
			}
			
			MobileMessaging.userAgent = GeoNotAvailableUserAgentStub()
			MobileMessaging.currentInstallation?.syncWithServer({ (error) in
				requestsCompleted.fulfill()
			})
		})
		
		self.waitForExpectations(timeout: 100) { err in
			
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
