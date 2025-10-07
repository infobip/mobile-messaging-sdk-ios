// 
//  Example/Tests/MobileMessagingTests/BaseSettingsTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
@testable import MobileMessaging

class BaseSettingsTests: XCTestCase {
	func testBaseSettings() {
		XCTAssertEqual(Consts.APIValues.prodDynamicBaseURLString, "https://mobile.infobip.com")
		XCTAssertEqual(Consts.APIValues.platformType, "APNS")
	}
}
