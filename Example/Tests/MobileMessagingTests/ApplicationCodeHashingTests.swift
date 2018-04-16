//
//  ApplicationCodeHashingTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 16/04/2018.
//

import Foundation
import XCTest
@testable import MobileMessaging

class ApplicationCodeHashingTests: XCTestCase {
	
	func testThatAppCodeHashCalculatedRightWay() {
		XCTAssertEqual("47469bd985", calculateAppCodeHash("3c59f6e341a6896fc15b8cd7e3f3fdf8-031a75db-fd8f-46b0-9f2b-a2e915d7b952"))
	}
}
