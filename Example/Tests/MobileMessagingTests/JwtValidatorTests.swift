//
//  MMJwtValidatorTests.swift
//  MobileMessagingExample
//
//  Created by Luka Ilic on 07.05.2025.
//

import XCTest
@testable import MobileMessaging

class MMJwtValidatorTests: MMTestCase {
    
    // MARK: - Structure Validation Tests
    
    func testEmptyJwtValidation() {
        // Test with empty token
        let emptyToken = ""
        
        do {
            try MMJwtValidator.validateStructure(emptyToken)
            XCTFail("Should throw an error for empty token")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, MMInternalErrorDomain)
            XCTAssertEqual(error.userInfo[MMJwtValidationErrorDetails] as? String, "Token is empty or blank.")
        }
    }
    
    func testBlankJwtValidation() {
        // Test with whitespace token
        let blankToken = "   "
        
        do {
            try MMJwtValidator.validateStructure(blankToken)
            XCTFail("Should throw an error for blank token")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, MMInternalErrorDomain)
            XCTAssertEqual(error.userInfo[MMJwtValidationErrorDetails] as? String, "Token is empty or blank.")
        }
    }
    
    func testInvalidPartsJwtValidation() {
        // Test with token that doesn't have 3 parts
        let invalidPartsToken = "header.payload"
        
        do {
            try MMJwtValidator.validateStructure(invalidPartsToken)
            XCTFail("Should throw an error for token without 3 parts")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, MMInternalErrorDomain)
            XCTAssertEqual(error.userInfo[MMJwtValidationErrorDetails] as? String, "Token must have three parts separated by dots.")
        }
    }
    
    func testInvalidHeaderJwtValidation() {
        // Test with token that has invalid Base64 header
        let invalidHeaderToken = "invalid-header.payload.signature"
        
        do {
            try MMJwtValidator.validateStructure(invalidHeaderToken)
            XCTFail("Should throw an error for token with invalid header")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, MMInternalErrorDomain)
            XCTAssertEqual(error.userInfo[MMJwtValidationErrorDetails] as? String, "Token header is not a valid Base64 encoded JSON object.")
        }
    }
    
    func testMissingHeaderFieldsJwtValidation() {
        // Create a token with missing header fields
        let header = ["alg": "HS256"] // Missing typ and kid
        let headerJson = try! JSONSerialization.data(withJSONObject: header)
        let headerBase64 = headerJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let incompleteHeaderToken = "\(headerBase64).payload.signature"
        
        do {
            try MMJwtValidator.validateStructure(incompleteHeaderToken)
            XCTFail("Should throw an error for token with missing header fields")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, MMInternalErrorDomain)
            XCTAssertTrue((error.userInfo[MMJwtValidationErrorDetails] as? String)?.contains("Missing JWT header fields:") ?? false)
        }
    }
    
    func testInvalidPayloadJwtValidation() {
        // Create a token with valid header but invalid payload
        let header = ["alg": "HS256", "typ": "JWT", "kid": "key-id"]
        let headerJson = try! JSONSerialization.data(withJSONObject: header)
        let headerBase64 = headerJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let invalidPayloadToken = "\(headerBase64).invalid-payload.signature"
        
        do {
            try MMJwtValidator.validateStructure(invalidPayloadToken)
            XCTFail("Should throw an error for token with invalid payload")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, MMInternalErrorDomain)
            XCTAssertEqual(error.userInfo[MMJwtValidationErrorDetails] as? String, "Token payload is not a valid Base64 encoded JSON object.")
        }
    }
    
    func testMissingClaimsJwtValidation() {
        // Create a token with valid header but missing claims in payload
        let header = ["alg": "HS256", "typ": "JWT", "kid": "key-id"]
        let headerJson = try! JSONSerialization.data(withJSONObject: header)
        let headerBase64 = headerJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let payload = ["sub": "1234567890"] // Missing other required claims
        let payloadJson = try! JSONSerialization.data(withJSONObject: payload)
        let payloadBase64 = payloadJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let missingClaimsToken = "\(headerBase64).\(payloadBase64).signature"
        
        do {
            try MMJwtValidator.validateStructure(missingClaimsToken)
            XCTFail("Should throw an error for token with missing claims")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, MMInternalErrorDomain)
            XCTAssertTrue((error.userInfo[MMJwtValidationErrorDetails] as? String)?.contains("Missing JWT claims:") ?? false)
        }
    }
    
    // MARK: - Expiration Tests
    
    func testExpiredJwtValidation() {
        // Create a token with an expired timestamp (1 hour in the past)
        let header = ["alg": "HS256", "typ": "JWT", "kid": "key-id"]
        let headerJson = try! JSONSerialization.data(withJSONObject: header)
        let headerBase64 = headerJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let expiredTime = Int(Date().timeIntervalSince1970 - 3600) // 1 hour ago
        let payload: [String: Any] = [
            "typ": "jwt",
            "sub": "user123",
            "infobip-api-key": "api-key-123",
            "iat": Int(Date().timeIntervalSince1970 - 7200), // 2 hours ago
            "exp": expiredTime,
            "jti": "jti-123"
        ]
        
        let payloadJson = try! JSONSerialization.data(withJSONObject: payload)
        let payloadBase64 = payloadJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let expiredToken = "\(headerBase64).\(payloadBase64).signature"
        
        do {
            try MMJwtValidator.checkTokenValidity(expiredToken)
            XCTFail("Should throw an error for expired token")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, MMInternalErrorDomain)
            XCTAssertEqual(error.userInfo[NSLocalizedDescriptionKey] as? String, "The provided JWT is expired.")
        }
        
        // Verify that isExpired returns true
        do {
            let isExpired = try MMJwtValidator.isExpired(expiredToken)
            XCTAssertTrue(isExpired, "Token should be identified as expired")
        } catch {
            XCTFail("Should not throw during isExpired check: \(error)")
        }
    }
    
    func testValidJwtToken() {
        // Create a token that's valid (expires 1 hour in the future)
        let header = ["alg": "HS256", "typ": "JWT", "kid": "key-id"]
        let headerJson = try! JSONSerialization.data(withJSONObject: header)
        let headerBase64 = headerJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let futureTime = Int(Date().timeIntervalSince1970 + 3600) // 1 hour in future
        let payload: [String: Any] = [
            "typ": "jwt",
            "sub": "user123",
            "infobip-api-key": "api-key-123",
            "iat": Int(Date().timeIntervalSince1970),
            "exp": futureTime,
            "jti": "jti-123"
        ]
        
        let payloadJson = try! JSONSerialization.data(withJSONObject: payload)
        let payloadBase64 = payloadJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let validToken = "\(headerBase64).\(payloadBase64).signature"
        
        // This should not throw
        do {
            try MMJwtValidator.checkTokenValidity(validToken)
        } catch {
            XCTFail("Should not throw for valid token: \(error)")
        }
        
        // Verify that isExpired returns false
        do {
            let isExpired = try MMJwtValidator.isExpired(validToken)
            XCTAssertFalse(isExpired, "Valid token should not be identified as expired")
        } catch {
            XCTFail("Should not throw during isExpired check: \(error)")
        }
    }
    
    func testNonNumericExpiration() {
        // Test with a token that has an invalid expiration format
        let header = ["alg": "HS256", "typ": "JWT", "kid": "key-id"]
        let headerJson = try! JSONSerialization.data(withJSONObject: header)
        let headerBase64 = headerJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let payload: [String: Any] = [
            "typ": "jwt",
            "sub": "user123",
            "infobip-api-key": "api-key-123",
            "iat": Int(Date().timeIntervalSince1970),
            "exp": "not-a-number", // Invalid exp format
            "jti": "jti-123"
        ]
        
        let payloadJson = try! JSONSerialization.data(withJSONObject: payload)
        let payloadBase64 = payloadJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        let invalidExpToken = "\(headerBase64).\(payloadBase64).signature"
        
        // This should be treated as expired
        do {
            let isExpired = try MMJwtValidator.isExpired(invalidExpToken)
            XCTAssertTrue(isExpired, "Token with invalid exp format should be treated as expired")
        } catch {
            XCTFail("Should not throw during isExpired check: \(error)")
        }
        
        // Checking validity should throw expiration error
        do {
            try MMJwtValidator.checkTokenValidity(invalidExpToken)
            XCTFail("Should throw an error for token with invalid exp format")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, MMInternalErrorDomain)
            XCTAssertEqual(error.userInfo[NSLocalizedDescriptionKey] as? String, "The provided JWT is expired.")
        }
    }
}
