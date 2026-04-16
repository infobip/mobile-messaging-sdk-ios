//
//  Example/Tests/MobileMessagingTests/EscapingQueryTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import XCTest
@testable import MobileMessaging

class EscapingQueryTests : XCTestCase {
	func testNumber() {
		let request = RequestData(
			applicationCode: "test",
			method: .get,
			path: .empty,
			parameters: ["number": 12321432]
		)
		let urlRequest = try! request.buildURLRequest(baseURL: URL(string: "http://url.com")!)
		XCTAssertEqual("http://url.com?number=12321432", urlRequest.url!.absoluteString)
	}

	func testBoolEncodesAsNumeric() {
		let request = RequestData(
			applicationCode: "test",
			method: .get,
			path: .empty,
			parameters: ["flag": true]
		)
		let urlRequest = try! request.buildURLRequest(baseURL: URL(string: "http://url.com")!)
		XCTAssertEqual("http://url.com?flag=1", urlRequest.url!.absoluteString)
	}

	func testBoolFalseEncodesAsZero() {
		let request = RequestData(
			applicationCode: "test",
			method: .get,
			path: .empty,
			parameters: ["flag": false]
		)
		let urlRequest = try! request.buildURLRequest(baseURL: URL(string: "http://url.com")!)
		XCTAssertEqual("http://url.com?flag=0", urlRequest.url!.absoluteString)
	}

	func testSpecialCharactersEncoding() {
		// Same characters as the original Alamofire testEscape: !*'();:@&=+$,/?%#[]
		let specialChars = "!*'();:@&=+$,/?%#[]"
		let request = RequestData(
			applicationCode: "test",
			method: .get,
			path: .empty,
			parameters: ["key": specialChars]
		)
		let urlRequest = try! request.buildURLRequest(baseURL: URL(string: "http://url.com")!)
		let query = URLComponents(url: urlRequest.url!, resolvingAgainstBaseURL: false)!.percentEncodedQuery!

		// Characters that URLComponents percent-encodes
		XCTAssertTrue(query.contains("%26"), "& must be encoded as %26")
		XCTAssertTrue(query.contains("%3D"), "= must be encoded as %3D")
		XCTAssertTrue(query.contains("%23"), "# must be encoded as %23")
		XCTAssertTrue(query.contains("%25"), "% must be encoded as %25")
		XCTAssertTrue(query.contains("%5B"), "[ must be encoded as %5B")
		XCTAssertTrue(query.contains("%5D"), "] must be encoded as %5D")

		// Characters that URLComponents leaves unencoded (legal in RFC 3986 query).
		// Alamofire encoded all sub-delimiters, but Foundation only encodes
		// structurally significant ones. These are safe unencoded per RFC 3986.
		for char: Character in ["!", "*", "'", "(", ")", ";", ":", "@", "+", "$", ",", "/", "?"] {
			XCTAssertTrue(query.contains(char), "\(char) is legal unencoded in query per RFC 3986")
		}
	}
}
