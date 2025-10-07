// 
//  Example/Tests/MobileMessagingTests/TimezoneFormatterTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
import Foundation

@testable import MobileMessaging

class TimezoneFormatterTests: XCTestCase {
	func shouldReturnProperTimezonFormat() {

		MobileMessaging.timeZone = TimeZone(secondsFromGMT: 0)!
		XCTAssertEqual(DateStaticFormatters.CurrentJavaCompatibleTimeZoneOffset, "GMT+00:00")

		MobileMessaging.timeZone = TimeZone(secondsFromGMT: Int(3.5 * 60.0 * 60.0))!
		XCTAssertEqual(DateStaticFormatters.CurrentJavaCompatibleTimeZoneOffset, "GMT+03:30")
	}
}
