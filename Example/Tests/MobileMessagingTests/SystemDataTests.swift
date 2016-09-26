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
		MobileMessaging.geofencingService = MMNotAvailableGeofencingServiceStub(storage: mobileMessagingInstance.storage!)
		MobileMessaging.userAgent = MMUserAgentStub()
		
		let requestsCompleted = expectationWithDescription("requestsCompleted")
		var initialSystemDataHash: Int!
		var updatedSystemDataHash: Int!
	
		let ctx = self.storage.mainThreadManagedObjectContext!
		if let installation = InstallationManagedObject.MM_findFirstInContext(context: ctx) {
			initialSystemDataHash = installation.systemDataHash.integerValue
		}
		
		MobileMessaging.geofencingService = MMAvailableGeofencingServiceStub(storage: mobileMessagingInstance.storage!)
		MobileMessaging.currentInstallation?.syncWithServer({ (error) in
			
			ctx.reset()
			if let installation = InstallationManagedObject.MM_findFirstInContext(context: ctx) {
				updatedSystemDataHash = installation.systemDataHash.integerValue
			}
			
			MobileMessaging.geofencingService = MMNotAvailableGeofencingServiceStub(storage: self.mobileMessagingInstance.storage!)
			MobileMessaging.currentInstallation?.syncWithServer({ (error) in
				requestsCompleted.fulfill()
			})
		})
		
		self.waitForExpectationsWithTimeout(100) { err in
			
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
