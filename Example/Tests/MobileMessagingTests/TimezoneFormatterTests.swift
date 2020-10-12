//
//  TimezoneFormatterTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 11/02/2019.
//
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
