//
//  MMCallNotificationData.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 19/07/2022.
//  Copyright © 2022 Infobip Ltd. All rights reserved.
//

import Foundation
import InfobipRTC
import PushKit

public struct MMWebRTCNotificationData {
    internal var inboundAppCall: IncomingApplicationCall?
    internal var customData: [AnyHashable: Any]?
    internal var pushPKCredentials: PKPushCredentials?
}
