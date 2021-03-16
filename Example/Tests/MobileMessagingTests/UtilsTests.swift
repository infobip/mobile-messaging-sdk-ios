//
//  UtilsTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 12.03.2021.
//

import XCTest
@testable import MobileMessaging

class UtilsTests: XCTestCase {

    func testChecksAnyValuesForNil() {
        let megaOptionalString: String?????? = nil
        let nilString: String? = nil
        let string: String = "some string"
        let dict: [String: Any] = ["nilString": nilString as Any]

        XCTAssertTrue(checkIfAnyIsNil(megaOptionalString as Any))
        XCTAssertTrue(checkIfAnyIsNil(dict["nilString"] as Any))
        XCTAssertTrue(checkIfAnyIsNil(dict["absentKey"] as Any))
        XCTAssertTrue(checkIfAnyIsNil(nilString as Any))
        XCTAssertFalse(checkIfAnyIsNil(string as Any))
    }
}
