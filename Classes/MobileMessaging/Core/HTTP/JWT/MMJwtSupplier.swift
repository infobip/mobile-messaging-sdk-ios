//
//  MMJwtSupplier.swift
//  MobileMessaging
//
//  Created by Luka Ilic on 28.04.2025.
//

import Foundation

/**
 * Protocol for supplying JSON Web Tokens (JWT) for API authorization.
 *
 * Implementations of this protocol supply JWT tokens that will be used
 * by the SDK to authorize API calls which support JWT-based authorization.
 */
@objc public protocol MMJwtSupplier {
    /**
     * Returns a JSON Web Token (JWT) for authorization.
     *
     * This method is called each time the SDK makes an API call that can use JWT authorization.
     * The returned token will be checked to ensure it has a valid structure and is not expired.
     * Return `nil` in case user is anonymous and has no external user ID in which case API key authorization will be used.
     *
     * - Returns: a JWT as a String, or `nil` if no token is available
     */
    @objc func getJwt() -> String?
}
