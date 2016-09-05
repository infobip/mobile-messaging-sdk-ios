//
//  SystemDataTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 29/08/16.
//

import XCTest
@testable import MobileMessaging

class MMUserAgentStub: MMUserAgent {
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

public class MMAvailableGeofencingServiceStub: MMGeofencingService {
	override var isAvailable: Bool  {
		return true
	}
}

public class MMNotAvailableGeofencingServiceStub: MMGeofencingService {
	override var isAvailable: Bool  {
		return false
	}
}


class SystemDataTests: MMTestCase {

    func testSystemDataUpdates() {
		
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		MobileMessaging.geofencingService = MMNotAvailableGeofencingServiceStub()
		MobileMessaging.userAgent = MMUserAgentStub()
		
		let requestsCompleted = expectation(description: "requestsCompleted")
		var initialSystemDataHash: Int!
		var updatedSystemDataHash: Int!
	
		let ctx = self.storage.mainThreadManagedObjectContext!
		if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
			initialSystemDataHash = installation.systemDataHash.intValue
		}
		
		MobileMessaging.geofencingService = MMAvailableGeofencingServiceStub()
		MobileMessaging.currentInstallation?.syncWithServer(completion: { (error) in
			
			ctx.reset()
			if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
				updatedSystemDataHash = installation.systemDataHash.intValue
			}
			
			MobileMessaging.geofencingService = MMNotAvailableGeofencingServiceStub()
			MobileMessaging.currentInstallation?.syncWithServer(completion: { (error) in
				requestsCompleted.fulfill()
			})
		})
		
		self.waitForExpectations(timeout: 100) { err in
			
			ctx.reset()
			if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
				XCTAssertEqual(initialSystemDataHash, 0)
				XCTAssertNotEqual(initialSystemDataHash, updatedSystemDataHash)
				XCTAssertNotEqual(installation.systemDataHash.intValue, initialSystemDataHash)
				XCTAssertNotEqual(installation.systemDataHash.intValue, updatedSystemDataHash)
			}
		}
    }
}
