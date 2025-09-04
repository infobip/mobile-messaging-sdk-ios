//
//  JwtSupplierTests.swift
//  MobileMessagingExample
//
//  Created by Luka Ilic on 16.05.2025.
//

import XCTest
@testable import MobileMessaging

class JwtSupplierTests: MMTestCase {
    
    private class MockJwtSupplier: MMJwtSupplier {
        var jwtToReturn: String?
        var getJwtCalled = false
        
        func getJwt() -> String? {
            getJwtCalled = true
            return jwtToReturn
        }
    }
    
    override func setUp() {
        super.setUp()
        MMTestCase.startWithCorrectApplicationCode()
    }
    
    override func tearDown() {
        // Clean up after each test
        MobileMessaging.jwtSupplier = nil
        super.tearDown()
    }
    
    func testWithJwtSupplier() {
        // Given
        let mockSupplier = MockJwtSupplier()
        mockSupplier.jwtToReturn = "mock.jwt.token"
        
        // When
        let mm = mobileMessagingInstance.withJwtSupplier(mockSupplier)
        
        // Then
        XCTAssertNotNil(mm)
        XCTAssertTrue(mm === mobileMessagingInstance, "Should return self for method chaining")
        XCTAssertNotNil(MobileMessaging.jwtSupplier)
        XCTAssertTrue((MobileMessaging.jwtSupplier as AnyObject) === (mockSupplier as AnyObject), "The supplier should be set correctly")
    }

    func testSetJwtSupplier() {
        // Given
        let mockSupplier = MockJwtSupplier()
        mockSupplier.jwtToReturn = "mock.jwt.token"
        let expectation = self.expectation(description: "JWT supplier set")

        // When
        MobileMessaging.jwtSupplier = mockSupplier

        // Then - wait for async operation to complete
        mobileMessagingInstance.queue.async {
            XCTAssertNotNil(MobileMessaging.jwtSupplier)
            XCTAssertTrue((MobileMessaging.jwtSupplier as AnyObject) === (mockSupplier as AnyObject), "The supplier should be set correctly")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testClearJwtSupplier() {
        // Given
        let mockSupplier = MockJwtSupplier()
        mockSupplier.jwtToReturn = "mock.jwt.token"
        MobileMessaging.jwtSupplier = mockSupplier

        let expectation = self.expectation(description: "JWT supplier cleared")

        // When
        MobileMessaging.jwtSupplier = nil

        // Then - wait for async operation to complete
        mobileMessagingInstance.queue.async {
            XCTAssertNil(MobileMessaging.jwtSupplier, "The supplier should be cleared")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0, handler: nil)
    }

    func testGetValidJwtAccessToken() {
        // Given
        let mockSupplier = MockJwtSupplier()
        let validJwt = createValidJwtToken(expiresIn: 3600) // Valid for 1 hour
        mockSupplier.jwtToReturn = validJwt
        MobileMessaging.jwtSupplier = mockSupplier

        let expectation = self.expectation(description: "Get valid JWT")
        var resultJwt: String?
        var resultError: Error?

        // When
        mobileMessagingInstance.queue.async {
            do {
                resultJwt = try MobileMessaging.sharedInstance?.getValidJwtAccessToken()
            } catch {
                resultError = error
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)

        // Then
        XCTAssertNil(resultError, "Should not throw an error for valid JWT")
        XCTAssertEqual(resultJwt, validJwt, "Should return the valid JWT from supplier")
        XCTAssertTrue(mockSupplier.getJwtCalled, "getJwt() should be called")
    }

    func testGetValidJwtAccessTokenWithExpiredToken() {
        // Given
        let mockSupplier = MockJwtSupplier()
        let expiredJwt = createValidJwtToken(expiresIn: -3600) // Expired 1 hour ago
        mockSupplier.jwtToReturn = expiredJwt
        MobileMessaging.jwtSupplier = mockSupplier

        let expectation = self.expectation(description: "Get expired JWT")
        var resultError: NSError?

        // When
        mobileMessagingInstance.queue.async {
            do {
                _ = try MobileMessaging.sharedInstance?.getValidJwtAccessToken()
            } catch let error as NSError {
                resultError = error
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)

        // Then
        XCTAssertNotNil(resultError, "Should throw an error for expired JWT")
        XCTAssertEqual(resultError?.domain, MMInternalErrorDomain, "Error domain should match")
        XCTAssertEqual(resultError?.userInfo[NSLocalizedDescriptionKey] as? String, "The provided JWT is expired.", "Error description should match")
        XCTAssertTrue(mockSupplier.getJwtCalled, "getJwt() should be called")
    }

    func testGetValidJwtAccessTokenWithNoSupplier() {
        // Given
        MobileMessaging.jwtSupplier = nil

        let expectation = self.expectation(description: "Get JWT with no supplier")
        var resultJwt: String?
        var resultError: Error?

        // When
        mobileMessagingInstance.queue.async {
            do {
                resultJwt = try MobileMessaging.sharedInstance?.getValidJwtAccessToken()
            } catch let error {
                resultError = error
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 2.0, handler: nil)

        // Then
        XCTAssertNil(resultError, "Should not throw an error when no supplier is set")
        XCTAssertNil(resultJwt, "Should return nil when no supplier is set")
    }

    // MARK: - Helper methods
    private func createValidJwtToken(expiresIn: TimeInterval) -> String {
        let header = ["alg": "HS256", "typ": "JWT", "kid": "key-id"]
        let headerJson = try! JSONSerialization.data(withJSONObject: header)
        let headerBase64 = headerJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let expTime = Int(Date().timeIntervalSince1970 + expiresIn)
        let payload: [String: Any] = [
            "typ": "jwt",
            "sub": "user123",
            "infobip-api-key": "api-key-123",
            "iat": Int(Date().timeIntervalSince1970),
            "exp": expTime,
            "jti": "jti-123"
        ]

        let payloadJson = try! JSONSerialization.data(withJSONObject: payload)
        let payloadBase64 = payloadJson.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return "\(headerBase64).\(payloadBase64).signature"
    }
}