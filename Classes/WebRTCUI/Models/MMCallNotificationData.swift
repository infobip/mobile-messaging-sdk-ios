//
//  MMCallNotificationData.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 19/07/2022.
//  Copyright © 2022 Infobip Ltd. All rights reserved.
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
