//
//  EscapingQueryTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 26.05.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import XCTest
@testable import MobileMessaging

class EscapingQueryTests : XCTestCase {
	
	func testNumber() {
		let query = MMHTTPRequestSerializer.queryFromParameters(["number":12321432])
		XCTAssertEqual("number=12321432", query)
	}
	
	func testEscape() {
		let query = MMHTTPRequestSerializer.queryFromParameters(["Key!*'();:@&=+$,/?%#[]": "Value!*'();:@&=+$,/?%#[]"])
		XCTAssertEqual("Key%21%2A%27%28%29%3B%3A%40%26%3D%2B%24%2C%2F%3F%25%23%5B%5D=Value%21%2A%27%28%29%3B%3A%40%26%3D%2B%24%2C%2F%3F%25%23%5B%5D", query)
	}
}