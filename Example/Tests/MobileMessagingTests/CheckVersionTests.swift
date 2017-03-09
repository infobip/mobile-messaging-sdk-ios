//
//  CheckVersionTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 14.10.16.
//

import XCTest
@testable import MobileMessaging

class VersionCheckRemoteAPIManagerMock: RemoteAPIManager {
	init(mmContext: MobileMessaging, onlineVersion: String) {
		super.init(baseUrl: "", applicationCode: "", mmContext: mmContext)
		self.versionFetchingQueue = MMRemoteAPIMock(baseURLString: "", appCode: "", mmContext: mmContext, performRequestCompanionBlock: nil, completionCompanionBlock: nil, responseSubstitution: { request -> JSON? in
			return JSON.parse("{\"platformType\": \"APNS\", \"libraryVersion\": \"\(onlineVersion)\", \"updateUrl\": \"https://github.com/infobip/mobile-messaging-sdk-ios\"}")
		})
	}
}

class VersionManagerMock: VersionManager {
	var newVersionWarningShowUpBlock: (() -> Void)?
	var upToDateCaseBlock: (() -> Void)?
	var waitBlock: (() -> Void)?
	init(mmContext: MobileMessaging, onlineVersion: String) {
		super.init(remoteApiManager: VersionCheckRemoteAPIManagerMock(mmContext: mmContext, onlineVersion: onlineVersion))
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
	var versionManager: VersionManagerMock!
	
	override func setUp() {
		super.setUp()
		UserDefaults.standard.removeObject(forKey: VersionCheck.lastCheckDateKey)
		UserDefaults.standard.synchronize()
		
		versionManager = VersionManagerMock(mmContext: self.mobileMessagingInstance, onlineVersion: mobileMessagingVersion)
		versionManager.lastCheckDate = nil
	}
	
	func testThatValidationTimeoutWorks() {
		weak var expectationUpToDate = self.expectation(description: "up to date case")
		weak var expectationCheckedAgain = self.expectation(description: "check again")
		weak var expectationWait = self.expectation(description: "must wait")
		weak var expectationAlertShown = self.expectation(description: "alert shown")
		
		
		// initially we are up to data:
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
			self.versionManager.remoteApiManager = VersionCheckRemoteAPIManagerMock(mmContext: self.mobileMessagingInstance, onlineVersion: self.distantFutureVersion)
			
			// if we validate again immediately after we discovered Up To Date status, we'll end up with a timeout
			self.versionManager.validateVersion() {
				
				// but after the timeout is expired (we move to the future here)
				self.versionManager.lastCheckDate =  self.versionManager.lastCheckDate?.addingTimeInterval(-self.versionManager.defaultTimeout)
				
				// we can validate again
				self.versionManager.validateVersion()
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
