//
//  MMWebRTCService+UI.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 19/08/2021.
//  Copyright © 2021 Infobip Ltd. All rights reserved.
//

import Foundation
import UIKit
import InfobipRTC

public extension MMWebRTCService {
    private func getNewCallController() -> MMCallController {
        let callController = MMCallController.new
        callController.modalPresentationStyle = .fullScreen
        return callController
    }
    
    private func getCallType(call: Call? = nil, applicationCall: ApplicationCall? = nil) -> MMCallType {
        if let call = call {
            let customData = call.options.customData
            if let type = customData[MMWebRTCUIConstants.clientType] as? String,
               type.uppercased() == MMWebRTCUIConstants.pstn {
                return .pstn
            }
            return call.hasLocalVideo() || call.hasRemoteVideo() ? .video : .audio
        } else if applicationCall != nil, let customData = MobileMessaging.webrtcService?.notificationData?.customData {
            if let type = customData[MMWebRTCUIConstants.clientType] as? String,
               type.uppercased() == MMWebRTCUIConstants.pstn {
                return .pstn
            }
            let isVideo = (customData[MMWebRTCUIConstants.isVideo] as? String) == "true"
            return isVideo ? .application_video : .application_audio
        }
        return .audio
    }
    
    func getInboundCallController(incoming applicationCall: ApplicationCall, establishedEvent: CallEstablishedEvent) -> MMCallController {
        let callController = getNewCallController()
        applicationCall.applicationCallEventListener = callController
        callController.activeApplicationCall = applicationCall
        callController.callEstablishedEvent = establishedEvent
        if let incomingCall = applicationCall as? IncomingApplicationCall {
            callController.counterpart = incomingCall.from
            callController.destinationName = incomingCall.fromDisplayName
        }
        callController.callType = getCallType(applicationCall: applicationCall)
        return callController
    }
    
    func getOutboundCallController(ongoing destination: String, from: String, destinationName: String?,
                    conversationId: String?, callType: MMCallType = .pstn) -> MMCallController {
        let callController = getNewCallController()
        callController.counterpart = destination
        callController.outboundFrom = from
        callController.destinationName = destinationName
        callController.outboundConversationId = conversationId
        callController.callType = callType
        return callController
    }
}

extension UIImage {
    convenience init?(mm_webrtcui_named: String) {
        self.init(named: mm_webrtcui_named, in: MMWebRTCService.resourceBundle, compatibleWith: nil)
    }
}

extension NSDataAsset {
    convenience init?(mm_webrtcui_named: String) {
        self.init(name: mm_webrtcui_named, bundle: MMWebRTCService.resourceBundle)
    }
}
