//
//  JWTClaims.swift
//  MobileChatExample
//
//  Created by Francisco Fortes on 25/01/2023.
//  Copyright © 2023 Infobip d.o.o. All rights reserved.
//

import SwiftJWT

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
}
