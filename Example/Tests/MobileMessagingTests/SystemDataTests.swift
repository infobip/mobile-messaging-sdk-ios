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
	override var isGeofencingServiceEnabled: Bool {
		return true
	}
}
class GeoNotAvailableUserAgentStub: UserAgentStub {
	override var isGeofencingServiceEnabled: Bool {
		return false
	}
}

class SystemDataTests: MMTestCase {

    func testSystemDataUpdates() {
		weak var requestsCompleted = expectation(description: "requestsCompleted")
		let ctx = self.storage.mainThreadManagedObjectContext!
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		var initialSystemDataHash: Int64!
		MobileMessaging.userAgent = GeoNotAvailableUserAgentStub()
		
		if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
			initialSystemDataHash = installation.systemDataHash
		}
		
		var updatedSystemDataHash: Int64!
		MobileMessaging.userAgent = GeoAvailableUserAgentStub()
		MobileMessaging.currentInstallation?.syncWithServer(completion: { (error) in
			
			ctx.reset()
			if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
				updatedSystemDataHash = installation.systemDataHash
			}
			
			MobileMessaging.userAgent = GeoNotAvailableUserAgentStub()
			MobileMessaging.currentInstallation?.syncWithServer(completion: { (error) in
				requestsCompleted?.fulfill()
			})
		})
		
		self.waitForExpectations(timeout: 60) { _ in
			
			ctx.reset()
			if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
				XCTAssertEqual(initialSystemDataHash, 0)
				XCTAssertNotEqual(initialSystemDataHash, updatedSystemDataHash)
				XCTAssertNotEqual(installation.systemDataHash, initialSystemDataHash)
				XCTAssertNotEqual(installation.systemDataHash, updatedSystemDataHash)
			}
		}
    }
}
