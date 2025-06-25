//
//  MMJwtUtils.swift
//  MobileMessaging
//
//  Created by Luka Ilic on 28.04.2025.
//

import Foundation

final class MMJwtValidator {
    public static let invalidToken: String = "JWT_TOKEN_STRUCTURE_INVALID"
    public static let expiredToken: String = "JWT_TOKEN_EXPIRED"
    
    private static let mandatoryHeaders: Set<String> = ["alg", "typ", "kid"]
    private static let mandatoryClaims: Set<String> = ["typ", "sub", "infobip-api-key", "iat", "exp", "jti"]
    
    /// Checks token structure validity and throws errors with detailed description of which part failed validaiton.
    static func validateStructure(_ jwt: String) throws {
        if jwt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw NSError(type: .JwtStructureValidationEmptyError)
        }
        let parts = jwt.split(separator: ".")
        if parts.count != 3 {
            throw NSError(type: .JwtStructureValidationThreePartsError)
        }
        // Header
        guard
            let headerData = Data(base64URLEncoded: String(parts[0])),
            let headerJson = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any]
        else {
            throw NSError(type: .JwtStructureValidationHeaderNotValidError)
        }
        let headerKeys = Set(headerJson.keys)
        if !mandatoryHeaders.isSubset(of: headerKeys) {
            let missing = mandatoryHeaders.subtracting(headerKeys)
            throw NSError(type: .JwtStructureValidationHeaderMissingFieldsError, description: "Missing JWT header fields: \(Array(missing))")
        }
        // Payload
        guard
            let payloadData = Data(base64URLEncoded: String(parts[1])),
            let payloadJson = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else {
            throw NSError(type: .JwtStructureValidationPayloadNotValidError)
        }
        let claimKeys = Set(payloadJson.keys)
        if !mandatoryClaims.isSubset(of: claimKeys) {
            let missing = mandatoryClaims.subtracting(claimKeys)
            throw NSError(type: .JwtStructureValidationMissingClaimsError, description: "Missing JWT claims: \(Array(missing))")
        }
    }
    
    /// Throws structure errors. Returns true if token is expired, or can't read exp, false otherwise.
    static func isExpired(_ jwt: String) throws -> Bool {
        try validateStructure(jwt)
        let parts = jwt.split(separator: ".")
        guard
            let payloadData = Data(base64URLEncoded: String(parts[1])),
            let payloadJson = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        else {
            return true
        }
        let exp: TimeInterval
        if let expInt = payloadJson["exp"] as? Int {
            exp = TimeInterval(expInt)
        } else if let expStr = payloadJson["exp"] as? String, let expDouble = TimeInterval(expStr) {
            exp = expDouble
        } else if let expDouble = payloadJson["exp"] as? Double {
            exp = expDouble
        } else {
            return true
        }
        let currentTimeSeconds = Date().timeIntervalSince1970
        return currentTimeSeconds >= exp
    }
    
    /// Throws structure errors or JwtExpirationError if expired.
    public static func checkTokenValidity(_ jwt: String) throws {
        if try isExpired(jwt) {
            throw NSError(type: .JwtExpirationError)
        }
    }
}

private extension Data {
    init?(base64URLEncoded input: String) {
        var base64 = input.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let rem = base64.count % 4
        if rem > 0 { base64 += String(repeating: "=", count: 4 - rem) }
        self.init(base64Encoded: base64)
    }
}

extension MobileMessaging {
    /// Attempts to get and validate a JWT via your MMJwtSupplier.
    /// - Throws: MMJwtValidator.checkTokenValidity errors
    /// - Returns: The JWT string, or nil if no supplier is set or token is nil.
    func getValidJwtAccessToken() throws -> String? {
        guard let jwtSupplier = MobileMessaging.jwtSupplier else { return nil }
        let jwt = jwtSupplier.getJwt()
        guard let jwt = jwt else { return nil }
        try MMJwtValidator.checkTokenValidity(jwt)
        return jwt
    }
}
