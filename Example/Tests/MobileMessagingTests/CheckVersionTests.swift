//
//  CheckVersionTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 14.10.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import XCTest
@testable import MobileMessaging

class CheckVersionTests: MMTestCase {
	
	override func setUp() {
		super.setUp()
		UserDefaults.standard.removeObject(forKey: "MMLibrary-LastCheckDateKey")
		UserDefaults.standard.synchronize()
	}
	
	func testVersionCheck() {
		
		weak var requestExp = expectation(description: "libraryVersionRequest")
		weak var responseExp = expectation(description: "libraryVersionResponse")
		let remoteAPIMock = MMRemoteAPIMock(baseURLString: MMTestConstants.kTestBaseURLString, appCode: MMTestConstants.kTestCorrectApplicationCode, performRequestCompanionBlock: { request in
			
			switch request {
			case (is MMGetLibraryVersionRequest):
				requestExp?.fulfill()
			default:
				break
			}
			
			}, completionCompanionBlock: { response in
				switch response {
				case let result as MMLibraryVersionResult:
					XCTAssertEqual(result.value?.libraryVersion, "1.0.3")
					XCTAssertEqual(result.value?.updateUrl, "https://github.com/infobip/mobile-messaging-sdk-ios")
					responseExp?.fulfill()
				default:
					break
				}
		})
		
		MMVersionManager.shared?.remoteApiQueue = remoteAPIMock
		MobileMessaging.sharedInstance?.start()
		
		waitForExpectations(timeout: 10, handler: nil)
	}
	
}
