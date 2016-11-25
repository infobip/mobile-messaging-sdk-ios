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
		XCTAssertEqual(MMAPIValues.kProdBaseURLString, "https://oneapi2.infobip.com")
		XCTAssertEqual(MMAPIValues.kPlatformType, "APNS")
	}
}
