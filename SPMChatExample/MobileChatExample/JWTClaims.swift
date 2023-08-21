//
//  JWTClaims.swift
//  MobileChatExample
//
//  Created by Francisco Fortes on 25/01/2023.
//  Copyright © 2023 Infobip d.o.o. All rights reserved.
//

import SwiftJWT
import MobileMessaging

import Foundation
struct JWTClaims: Claims {
    let jti: String //random UNIQUE String
    let sub: String //'[email.@email.com | +PhoneNumber | ExtPersonID]'
    let stp: String //Define what's the above. ie: "email", "msisdn" or "externalPersonId".
    let iss: String // Widget ID
    let iat: Date //timestamp. Mandatory. Issue time when created
    let exp: Date //timestamp. Optional, e.g. when this token should be invalidated if not yet used,
    let ski: String //securityKey.id
    let sid: String //'Session Identifier'
    
    static func generateJWT(_ identityMode: String, identifier: String) -> String? {
        let widgetId = "<# your widget ID #>" // All this values can be obtained in your widget's configuration
        let widgetKeyId = "<# your widget key ID #>" // Always define key and secret as obfuscated strings, for safety!!
        let widgetSecretKeyId = "<# your widget secret key ID #>"
        let myHeader = Header()
        let randomUniqueString = UUID().uuidString
        let myClaims = JWTClaims(
            jti: randomUniqueString,
            sub: identifier,
            stp: identityMode,
            iss: widgetId,
            iat: Date(),
            exp: Date().addingTimeInterval(20), // 20 seconds after creation - recommended value
            ski: widgetKeyId,
            sid: randomUniqueString) // This is potentially not needed once we use Logout function
        var myJWT = JWT(header: myHeader, claims: myClaims)
        guard let secretKeyIdData = Data(base64Encoded: widgetSecretKeyId, options: .ignoreUnknownCharacters) else {
            MMLogError("Unable to decode the base64 secret key Id")
            return nil
        }
        let jwtSigner = JWTSigner.hs256(key: secretKeyIdData)
        guard let signedJWT = try? myJWT.sign(using: jwtSigner) else {
            MMLogError("Unable to prepare the signed JWT to authenticate into the chat")
            return nil
        }
        return signedJWT
    }

}
