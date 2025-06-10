//
//  JwtSupplierExampleImpl.swift
//  MobileMessagingExample
//
//  Created by Luka Ilic on 10.05.2025..
//

import Foundation
import SwiftJWT
import MobileMessaging

private struct ExampleJwtClaims: Claims {
    let typ: String
    let jti: String
    let sub: String
    let iss: String
    let iat: Date
    let exp: Date
    let infobip_api_key: String
    enum CodingKeys: String, CodingKey {
        case typ, jti, sub, iss, iat, exp
        case infobip_api_key = "infobip-api-key"
    }
}

/// Helper to convert hex string to Data
private func hexStringToData(_ hex: String) -> Data? {
    var hex = hex
    if hex.hasPrefix("0x") { hex = String(hex.dropFirst(2)) }
    var data = Data()
    var tempHex = hex
    while tempHex.count > 0 {
        let c = String(tempHex.prefix(2))
        tempHex = String(tempHex.dropFirst(2))
        if let byte = UInt8(c, radix: 16) {
            data.append(byte)
        } else {
            return nil
        }
    }
    return data
}

public class JwtSupplierExampleImpl: MMJwtSupplier {
    /// The external user id to use for subject claim
    private var externalUserId: String? = nil

    public func setExternalUserId(_ externalUserId: String?) {
        self.externalUserId = externalUserId
    }

    /// Returns a JWT or `nil` (see protocol documentation)
    public func getJwt() -> String? {
        guard let externalUserId = self.externalUserId else { return nil }
        do {
            return try generateSignedJwt(externalUserId: externalUserId)
        } catch {
            return nil
        }
    }
    
    // MARK: JWT generation with static secret (for demo/testing—DO NOT use in production, instead call your backend to generate the JWT)
    private func generateSignedJwt(externalUserId: String) throws -> String {
        // TODO: Replace these with your actual credentials
        let secretKeyHex = "<secret-key-hex>"
        let keyId = "<key-id>"
        let applicationCode = "<app-code>"
        
        guard let secretData = hexStringToData(secretKeyHex) else {
            throw NSError(domain: "JwtSupplierExampleImpl", code: 0, userInfo: [NSLocalizedDescriptionKey: "Secret key is not valid hex"])
        }

        let now = Date()
        let exp = now.addingTimeInterval(0)

        let claims = ExampleJwtClaims(
            typ: "Bearer",
            jti: UUID().uuidString,
            sub: externalUserId,
            iss: applicationCode,
            iat: now,
            exp: exp,
            infobip_api_key: applicationCode
        )

        let header = Header(typ: "JWT", kid: keyId)

        var jwt = JWT(header: header, claims: claims)
        let signer = JWTSigner.hs256(key: secretData)
        let signed = try jwt.sign(using: signer)
        return signed
    }
}

public class JwtSupplierExampleNilImpl: MMJwtSupplier {
    public func getJwt() -> String? {
        return nil
    }
}
