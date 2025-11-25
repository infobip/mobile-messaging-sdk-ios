//
//  UserDataValidator.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

/**
 Validator for user data fields against People API limits.
 Validates fields before sending to the backend to ensure compliance with API constraints.

 - See also: [People API Documentation](https://www.infobip.com/docs/api/customer-engagement/people/update-a-person)
 */
class UserDataValidator {

    // Field names and their maximum length limits
    private enum Field {
        case firstName
        case lastName
        case middleName
        case externalUserId
        case email(String)  // Associated value for specific email in error message

        var name: String {
            switch self {
            case .firstName: return "firstName"
            case .lastName: return "lastName"
            case .middleName: return "middleName"
            case .externalUserId: return "externalUserId"
            case .email(let address): return "email '\(address)'"
            }
        }

        var maxLength: Int {
            switch self {
            case .firstName: return 255
            case .lastName: return 255
            case .middleName: return 50
            case .externalUserId: return 256
            case .email: return 255
            }
        }
    }

    // Collection size limits
    private static let MAX_EMAIL_COUNT = 100
    private static let MAX_PHONE_COUNT = 100
    private static let MAX_CUSTOM_ATTRIBUTE_VALUE_LENGTH = 4096

    private static let DOCS_URL = "https://www.infobip.com/docs/api/customer-engagement/people/update-a-person"

    /**
     Validates user data against People API field limits.

     - Parameter user: The user object to validate
     - Throws: Error if validation fails
     */
    static func validate(user: MMUser) throws {
        var errors = [String]()

        validateStringFieldLength(user.externalUserId, field: .externalUserId, errors: &errors)
        validateStringFieldLength(user.firstName, field: .firstName, errors: &errors)
        validateStringFieldLength(user.middleName, field: .middleName, errors: &errors)
        validateStringFieldLength(user.lastName, field: .lastName, errors: &errors)
        validateEmails(user.emails, errors: &errors)
        validatePhones(user.phones, errors: &errors)
        validateCustomAttributes(user.customAttributes, errors: &errors)

        if !errors.isEmpty {
            try throwValidationException(errors: errors)
        }
    }

    /**
     Validates user identity data against People API field limits.

     - Parameter userIdentity: The user identity object to validate
     - Throws: Error if validation fails
     */
    static func validate(userIdentity: MMUserIdentity) throws {
        var errors = [String]()

        validateStringFieldLength(userIdentity.externalUserId, field: .externalUserId, errors: &errors)
        validateEmails(userIdentity.emails, errors: &errors)
        validatePhones(userIdentity.phones, errors: &errors)

        if !errors.isEmpty {
            try throwValidationException(errors: errors)
        }
    }

    /**
     Validates user attributes data against People API field limits.

     - Parameter userAttributes: The user attributes object to validate, can be nil
     - Throws: Error if validation fails
     */
    static func validate(userAttributes: MMUserAttributes?) throws {
        guard let userAttributes = userAttributes else {
            return
        }

        var errors = [String]()

        validateStringFieldLength(userAttributes.firstName, field: .firstName, errors: &errors)
        validateStringFieldLength(userAttributes.middleName, field: .middleName, errors: &errors)
        validateStringFieldLength(userAttributes.lastName, field: .lastName, errors: &errors)
        validateCustomAttributes(userAttributes.customAttributes, errors: &errors)

        if !errors.isEmpty {
            try throwValidationException(errors: errors)
        }
    }

    private static func validateStringFieldLength(_ value: String?, field: Field, errors: inout [String]) {
        if let value = value, value.count > field.maxLength {
            errors.append(String(format: "%@ exceeds maximum length of %d characters (actual: %d)",
                                field.name, field.maxLength, value.count))
        }
    }

    private static func validateEmails(_ emails: [String]?, errors: inout [String]) {
        guard let emails = emails else {
            return
        }

        if emails.count > MAX_EMAIL_COUNT {
            errors.append(String(format: "emails count exceeds maximum of %d (actual: %d)",
                                MAX_EMAIL_COUNT, emails.count))
        }

        // Validate individual email lengths
        for email in emails {
            validateStringFieldLength(email, field: .email(email), errors: &errors)
        }
    }

    private static func validatePhones(_ phones: [String]?, errors: inout [String]) {
        if let phones = phones, phones.count > MAX_PHONE_COUNT {
            errors.append(String(format: "phones count exceeds maximum of %d (actual: %d)",
                                MAX_PHONE_COUNT, phones.count))
        }
    }

    private static func validateCustomAttributes(_ customAttributes: [String: MMAttributeType]?, errors: inout [String]) {
        guard let customAttributes = customAttributes else {
            return
        }

        for (key, value) in customAttributes {
            let valueAsString: String

            // For NSArray types (CustomList in Java), calculate JSON serialized length
            if let arrayValue = value as? NSArray {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: arrayValue, options: [])
                    valueAsString = String(data: jsonData, encoding: .utf8) ?? ""
                } catch {
                    MMLogError("Failed to serialize CustomList attribute '\(key)': \(error.localizedDescription)")
                    continue
                }
            } else {
                valueAsString = "\(value)"
            }

            if valueAsString.count > MAX_CUSTOM_ATTRIBUTE_VALUE_LENGTH {
                errors.append(String(format: "customAttribute '%@' value exceeds maximum length of %d characters (actual: %d)",
                                    key, MAX_CUSTOM_ATTRIBUTE_VALUE_LENGTH, valueAsString.count))
            }
        }
    }

    private static func throwValidationException(errors: [String]) throws {
        var message = "User data validation failed:\n"
        for error in errors {
            message += "  - \(error)\n"
        }
        message += "\nPlease check the field limits at: \(DOCS_URL)"

        MMLogError(message)

        throw NSError(type: .UserDataValidationError, description: message)
    }
}
