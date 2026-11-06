//
//  InboxExample/InboxExample/App/JWTSigner.swift
//  InboxExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import CryptoKit

/// Signs the inbox JWT on the device with the key from "JWT private keys for mobile app inbox" on the App Profile.
///
/// For trying JWT authorization without a backend only. Never ship the secret key in an app: anyone who extracts it
/// can read and delete every user's inbox. See "JSON Web Token (JWT) structure and generation example" in the SDK wiki
/// for how your backend should sign the token.
struct JWTSigner {
    let applicationCode: String
    let keyId: String
    let secretKeyHex: String

    func sign(externalUserId: String, now: Date = Date()) throws -> String {
        guard let secret = Data(hex: secretKeyHex) else {
            throw JWTSignerError.invalidSecretKey
        }
        let issuedAt = Int(now.timeIntervalSince1970)
        let header: [String: Any] = ["alg": "HS256", "typ": "JWT", "kid": keyId]
        let claims: [String: Any] = [
            "typ": "Bearer",
            "jti": UUID().uuidString,
            "sub": externalUserId,
            "iss": applicationCode,
            "iat": issuedAt,
            "exp": issuedAt + 60,
            "infobip-api-key": applicationCode
        ]
        let signingInput = try Self.base64URL(JSONSerialization.data(withJSONObject: header, options: .sortedKeys))
            + "." + Self.base64URL(JSONSerialization.data(withJSONObject: claims, options: .sortedKeys))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(signingInput.utf8), using: SymmetricKey(data: secret))
        return signingInput + "." + Self.base64URL(Data(signature))
    }

    static func base64URL(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

enum JWTSignerError: LocalizedError {
    case invalidSecretKey

    var errorDescription: String? {
        return "The JWT secret key is not a valid hex string."
    }
}

private extension Data {
    init?(hex: String) {
        guard !hex.isEmpty, hex.count % 2 == 0 else {
            return nil
        }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = next
        }
        self = data
    }
}
