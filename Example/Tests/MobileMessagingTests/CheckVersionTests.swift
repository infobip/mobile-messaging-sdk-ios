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
		NSUserDefaults.standardUserDefaults().removeObjectForKey("MMLibrary-LastCheckDateKey")
		NSUserDefaults.standardUserDefaults().synchronize()
	}
	
	func testVersionCheck() {
		
		weak var requestExp = expectationWithDescription("libraryVersionRequest")
		weak var responseExp = expectationWithDescription("libraryVersionResponse")
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
		
		waitForExpectationsWithTimeout(10, handler: nil)
	}
	
}
