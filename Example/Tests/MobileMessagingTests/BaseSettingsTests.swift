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
		XCTAssertEqual(Consts.APIValues.prodDynamicBaseURLString, "https://mobile.infobip.com")
		XCTAssertEqual(Consts.APIValues.platformType, "APNS")
	}
}
