//
//  BaseSettingsTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 24.11.16.
//

import XCTest
@testable import MobileMessaging

class BaseSettingsTests: XCTestCase {
	func testBaseSettings() {
		XCTAssertEqual(APIValues.prodBaseURLString, "https://oneapi2.infobip.com")
		XCTAssertEqual(APIValues.platformType, "APNS")
	}
}
