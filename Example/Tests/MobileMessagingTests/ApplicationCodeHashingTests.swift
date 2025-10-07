// 
//  Example/Tests/MobileMessagingTests/ApplicationCodeHashingTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import XCTest
@testable import MobileMessaging

class ApplicationCodeHashingTests: XCTestCase {
    
    func testThatAppCodeHashCalculatedRightWay() {
        XCTAssertEqual("b9ff7d254e", calculateAppCodeHash("3c59f6e341a6896fc15b8cd7e3f3fdf8-031a75db-fd8f-46b0-9f2b-a2e915d7b952"))
    }
}
