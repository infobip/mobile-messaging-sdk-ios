// 
//  Example/Tests/MobileMessagingTests/EscapingQueryTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import XCTest
@testable import MobileMessaging

class EscapingQueryTests : XCTestCase {
	func testNumber() {
		let urlRequest = try! URLEncoding.queryString.encode(
			URLRequest(url: URL(string: "http://url.com")!),
			with: ["number":12321432]
		)
		XCTAssertEqual("http://url.com?number=12321432", urlRequest.url!.absoluteString)
	}

	func testEscape() {
		let urlRequest = try! URLEncoding.queryString.encode(
			URLRequest(url: URL(string: "http://url.com")!),
			with: ["Key!*'();:@&=+$,/?%#[]": "Value!*'();:@&=+$,/?%#[]"]
		)
		XCTAssertEqual(
			"http://url.com?Key%21%2A%27%28%29%3B%3A%40%26%3D%2B%24%2C/?%25%23%5B%5D=Value%21%2A%27%28%29%3B%3A%40%26%3D%2B%24%2C/?%25%23%5B%5D",
			urlRequest.url!.absoluteString)
	}
}
