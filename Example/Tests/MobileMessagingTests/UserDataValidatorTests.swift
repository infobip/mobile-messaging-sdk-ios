//
//  UserDataValidatorTests.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import XCTest
@testable import MobileMessaging

class UserDataValidatorTests: XCTestCase {

    // MARK: - MMUser Validation Tests

    func testValidUser() {
        let user = MMUser.empty
        user.firstName = "John"
        user.lastName = "Doe"
        user.emails = ["john.doe@example.com"]
        user.phones = ["+1234567890"]

        XCTAssertNoThrow(try UserDataValidator.validate(user: user))
    }

    func testUserWithTooLongFirstName() {
        let user = MMUser.empty
        user.firstName = String(repeating: "a", count: 256)

        XCTAssertThrowsError(try UserDataValidator.validate(user: user)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "com.mobile-messaging.internal")
            XCTAssertTrue(nsError.localizedDescription.contains("firstName"))
            XCTAssertTrue(nsError.localizedDescription.contains("255"))
        }
    }

    func testUserWithTooLongMiddleName() {
        let user = MMUser.empty
        user.middleName = String(repeating: "c", count: 51)

        XCTAssertThrowsError(try UserDataValidator.validate(user: user)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("middleName"))
            XCTAssertTrue(nsError.localizedDescription.contains("50"))
        }
    }

    func testUserWithTooLongExternalUserId() {
        let user = MMUser.empty
        user.externalUserId = String(repeating: "x", count: 257)

        XCTAssertThrowsError(try UserDataValidator.validate(user: user)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("externalUserId"))
            XCTAssertTrue(nsError.localizedDescription.contains("256"))
        }
    }

    func testUserWithTooManyEmails() {
        let user = MMUser.empty
        user.emails = (1...101).map { "user\($0)@example.com" }

        XCTAssertThrowsError(try UserDataValidator.validate(user: user)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("emails"))
            XCTAssertTrue(nsError.localizedDescription.contains("100"))
        }
    }

    func testUserWithTooLongEmail() {
        let user = MMUser.empty
        let localPart = String(repeating: "a", count: 250)
        user.emails = ["\(localPart)@example.com"]

        XCTAssertThrowsError(try UserDataValidator.validate(user: user)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("email"))
            XCTAssertTrue(nsError.localizedDescription.contains("255"))
        }
    }

    func testUserWithTooManyPhones() {
        let user = MMUser.empty
        user.phones = (1...101).map { "+1234567890\($0)" }

        XCTAssertThrowsError(try UserDataValidator.validate(user: user)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("phones"))
            XCTAssertTrue(nsError.localizedDescription.contains("100"))
        }
    }

    func testUserWithMultipleValidationErrors() {
        let user = MMUser.empty
        user.firstName = String(repeating: "a", count: 256)
        user.emails = (1...101).map { "user\($0)@example.com" }

        XCTAssertThrowsError(try UserDataValidator.validate(user: user)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("firstName"))
            XCTAssertTrue(nsError.localizedDescription.contains("emails"))
        }
    }

    // MARK: - MMUserIdentity Validation Tests

    func testValidUserIdentity() {
        let identity = MMUserIdentity(phones: ["+1234567890"], emails: ["user@example.com"], externalUserId: "user123")

        XCTAssertNotNil(identity)
        XCTAssertNoThrow(try UserDataValidator.validate(userIdentity: identity!))
    }

    func testUserIdentityWithTooLongExternalUserId() {
        let identity = MMUserIdentity(phones: nil, emails: nil, externalUserId: String(repeating: "x", count: 257))

        XCTAssertNotNil(identity)
        XCTAssertThrowsError(try UserDataValidator.validate(userIdentity: identity!)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("externalUserId"))
            XCTAssertTrue(nsError.localizedDescription.contains("256"))
        }
    }

    func testUserIdentityWithTooManyEmails() {
        let emails = (1...101).map { "user\($0)@example.com" }
        let identity = MMUserIdentity(phones: nil, emails: emails, externalUserId: nil)

        XCTAssertNotNil(identity)
        XCTAssertThrowsError(try UserDataValidator.validate(userIdentity: identity!)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("emails"))
            XCTAssertTrue(nsError.localizedDescription.contains("100"))
        }
    }

    // MARK: - MMUserAttributes Validation Tests

    func testValidUserAttributes() {
        let attributes = MMUserAttributes(
            firstName: "John",
            middleName: "Michael",
            lastName: "Doe",
            tags: ["premium"],
            gender: .Male,
            birthday: Date(),
            customAttributes: ["level": 5 as NSNumber]
        )

        XCTAssertNoThrow(try UserDataValidator.validate(userAttributes: attributes))
    }

    func testUserAttributesWithTooLongFirstName() {
        let attributes = MMUserAttributes(
            firstName: String(repeating: "a", count: 256),
            middleName: nil,
            lastName: nil,
            tags: nil,
            gender: nil,
            birthday: nil,
            customAttributes: nil
        )

        XCTAssertThrowsError(try UserDataValidator.validate(userAttributes: attributes)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("firstName"))
        }
    }

    // MARK: - Custom Attributes Validation Tests

    func testCustomAttributeWithTooLongValue() {
        let user = MMUser.empty
        user.firstName = "John"
        user.customAttributes = [
            "longValue": String(repeating: "a", count: 4097) as NSString
        ]

        XCTAssertThrowsError(try UserDataValidator.validate(user: user)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("customAttribute"))
            XCTAssertTrue(nsError.localizedDescription.contains("longValue"))
            XCTAssertTrue(nsError.localizedDescription.contains("4096"))
        }
    }

    func testCustomAttributeWithMixedTypes() {
        let user = MMUser.empty
        user.firstName = "John"
        user.customAttributes = [
            "stringValue": "test" as NSString,
            "numberValue": 42 as NSNumber,
            "dateValue": Date() as NSDate
        ]

        XCTAssertNoThrow(try UserDataValidator.validate(user: user))
    }

    func testCustomAttributeArrayTooLong() {
        let user = MMUser.empty
        user.firstName = "John"

        var largeArray: [[String: MMAttributeType]] = []
        for i in 1...200 {
            largeArray.append([
                "name": "Item\(i)" as NSString,
                "value": String(repeating: "x", count: 50) as NSString
            ])
        }

        user.customAttributes = ["largeItems": largeArray as NSArray]

        XCTAssertThrowsError(try UserDataValidator.validate(user: user)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("customAttribute"))
            XCTAssertTrue(nsError.localizedDescription.contains("4096"))
        }
    }

    // MARK: - Edge Cases

    func testUserWithUnicodeCharacters() {
        let user = MMUser.empty
        user.firstName = "José"
        user.lastName = "李明"

        XCTAssertNoThrow(try UserDataValidator.validate(user: user))
    }

    func testValidationErrorContainsDocumentationLink() {
        let user = MMUser.empty
        user.firstName = String(repeating: "a", count: 256)

        XCTAssertThrowsError(try UserDataValidator.validate(user: user)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("www.infobip.com"))
        }
    }
}
