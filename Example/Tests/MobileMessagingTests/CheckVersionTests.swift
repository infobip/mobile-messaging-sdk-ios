//
//  CheckVersionTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 14.10.16.
//

import XCTest
@testable import MobileMessaging

class CheckVersionTests: MMTestCase {
	
	override func setUp() {
		super.setUp()
		UserDefaults.standard.removeObject(forKey: "MMLibrary-LastCheckDateKey")
		UserDefaults.standard.synchronize()
		MMVersionManager.shared?.lastCheckDate = nil
	}
	
//	func testVersionCheck() {
//		cleanUpAndStop()
//		
//		weak var requestExp = expectation(description: "libraryVersionRequest")
//		weak var responseExp = expectation(description: "libraryVersionResponse")
//		let remoteAPIMock = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestCorrectApplicationCode, performRequestCompanionBlock: { request in
//			
//			switch request {
//			case (is MMGetLibraryVersionRequest):
//				requestExp?.fulfill()
//			default:
//				break
//			}
//			
//			}, completionCompanionBlock: { response in
//				switch response {
//				case let result as MMLibraryVersionResult:
//					XCTAssertEqual(result.value?.libraryVersion, "1.0.3")
//					XCTAssertEqual(result.value?.updateUrl, "https://github.com/infobip/mobile-messaging-sdk-ios")
//					responseExp?.fulfill()
//				default:
//					break
//				}
//		})
//		
//		MMVersionManager.shared?.remoteApiQueue = remoteAPIMock
//		MobileMessaging.sharedInstance?.start()
//		
//		waitForExpectations(timeout: 60, handler: nil)
//	}
	
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
