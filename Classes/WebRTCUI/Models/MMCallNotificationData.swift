// 
//  MMCallNotificationData.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import PushKit
#if WEBRTCUI_ENABLED
import InfobipRTC

public struct MMWebRTCNotificationData {
    internal var activeCall: ActiveCall?
    internal var customData: [AnyHashable: Any]?
    internal var pushPKCredentials: PKPushCredentials?
    internal var hasVideo: Bool {
        if let customData = customData,
           let isVideoString = customData["isVideo"] as? String {
            return isVideoString == "true" ? true : false
        }
        return false
    }
}
#endif
