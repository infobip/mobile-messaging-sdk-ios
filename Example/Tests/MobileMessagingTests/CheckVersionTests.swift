//
//  CheckVersionTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 14.10.16.
//

import XCTest
@testable import MobileMessaging

class VersionCheckRemoteAPIManagerMock: RemoteAPIManager {
	init(onlineVersion: String) {
		super.init(baseUrl: "", applicationCode: "")
		self.versionFetchingQueue = MMRemoteAPIMock(baseURLString: "", appCode: "", performRequestCompanionBlock: nil, completionCompanionBlock: nil, responseSubstitution: { request -> JSON? in
			return JSON.parse("{\"platformType\": \"APNS\", \"libraryVersion\": \"\(onlineVersion)\", \"updateUrl\": \"https://github.com/infobip/mobile-messaging-sdk-ios\"}")
		})
	}
}

class VersionManagerMock: VersionManager {
	var newVersionWarningShowUpBlock: (() -> Void)?
	var upToDateCaseBlock: (() -> Void)?
	var waitBlock: (() -> Void)?
	init(onlineVersion: String) {
		super.init()
		self.remoteApiManager = VersionCheckRemoteAPIManagerMock(onlineVersion: onlineVersion)
	}
	
	override func showNewVersionWarning(localVersion: String, response: LibraryVersionResponse) {
		newVersionWarningShowUpBlock?()
	}
	
	override func waitUntilItsTime() {
		super.waitUntilItsTime()
		waitBlock?()
	}
	
	override func handleUpToDateCase() {
		super.handleUpToDateCase()
		upToDateCaseBlock?()
	}
}

class CheckVersionTests: MMTestCase {
	let distantFutureVersion = "99.0.0"
	override func setUp() {
		UserDefaults.standard.removeObject(forKey: VersionCheck.lastCheckDateKey)
		UserDefaults.standard.synchronize()
		VersionManagerMock.shared.lastCheckDate = nil
	}
	
	func testThatValidationTimeoutWorks() {
		weak var expectationUpToDate = self.expectation(description: "up to date case")
		weak var expectationCheckedAgain = self.expectation(description: "check again")
		weak var expectationWait = self.expectation(description: "must wait")
		weak var expectationAlertShown = self.expectation(description: "alert shown")
		
		
		// initially we are up to data:
		let versionManager = VersionManagerMock(onlineVersion: mobileMessagingVersion)
		versionManager.upToDateCaseBlock = {
			expectationUpToDate?.fulfill()
		}
		versionManager.waitBlock = {
			expectationWait?.fulfill()
		}
		versionManager.newVersionWarningShowUpBlock = {
			expectationCheckedAgain?.fulfill()
			expectationAlertShown?.fulfill()
		}
		
		versionManager.validateVersion() {
			
			// then version increases
			versionManager.remoteApiManager = VersionCheckRemoteAPIManagerMock(onlineVersion: self.distantFutureVersion)
			
			// if we validate again immediately after we discovered Up To Date status, we'll end up with a timeout
			versionManager.validateVersion() {
				
				// but after the timeout is expired (we move to the future here)
				versionManager.lastCheckDate =  versionManager.lastCheckDate?.addingTimeInterval(-versionManager.defaultTimeout)
				
				// we can validate again
				versionManager.validateVersion()
			}
		}
		
		waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testVersionComparison() {
		do {
			let v1 = "1.0.0"
			let v2 = "2.0.0"
			XCTAssert(try! String.compareVersionNumbers(v1, v2) == ComparisonResult.orderedAscending)
		}
		
		do {
			let v1 = "1.0.0"
			let v2 = "1.0.1"
			XCTAssert(try! String.compareVersionNumbers(v1, v2) == ComparisonResult.orderedAscending)
		}
		
		do {
			let v1 = "0.1.0"
			let v2 = "0.1.1"
			XCTAssert(try! String.compareVersionNumbers(v1, v2) == ComparisonResult.orderedAscending)
		}
		
		do {
			let v1 = "0.1.0"
			let v2 = "0.1.0"
			XCTAssert(try! String.compareVersionNumbers(v1, v2) == ComparisonResult.orderedSame)
		}
		
		do {
			let v1 = "0.0.1"
			let v2 = "0.0.2"
			XCTAssert(try! String.compareVersionNumbers(v1, v2) == ComparisonResult.orderedAscending)
		}
	}
	
}
