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
    let sub: String //'[email.@email.com | +PhoneNumber | ExtPersonID]' => Only injected param together with stp once we have final authorisation
    let stp: String //Define what's the above. ie: "email", "msisdn" or "externalPersonId". We support email only as input, same as app
    let iss: String //Widget ID from portal
    let iat: Date //timestamp. Mandatory. Issue time when created
    let exp: Date //timestamp. Optional, e.g. when this token should be invalidated if not yet used,
    // if not set then by default token will be invalidated after 15 seconds after issueTime
    let ski: String //securityKey.id (left part provided by widget, different that widget id when copy button is tapped
    let sid: String //'Session Identifier' => session token provided by auth API
}
