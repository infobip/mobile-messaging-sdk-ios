// 
//  MMWebRTCService+UI.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UIKit
#if WEBRTCUI_ENABLED
import InfobipRTC

public extension MMWebRTCService {
    
    private func getCallType(call: Call? = nil, applicationCall: ApplicationCall? = nil) -> MMCallType {
        if let call = call as? WebrtcCall {
            let customData = call.options.customData
            if let type = customData[MMWebRTCUIConstants.clientType],
               type.uppercased() == MMWebRTCUIConstants.pstn {
                return .pstn
            }
            return call.hasCameraVideo() || call.hasRemoteCameraVideo() ? .video : .audio
        } else if applicationCall != nil, let customData = MobileMessaging.webRTCService?.notificationData?.customData {
            if let type = customData[MMWebRTCUIConstants.clientType] as? String,
               type.uppercased() == MMWebRTCUIConstants.pstn {
                return .pstn
            }
            
            let isVideo = (customData[MMWebRTCUIConstants.isVideo] as? String) == "true"
            return isVideo ? .application_video : .application_audio
        }
        return .audio
    }
    
    @MainActor
    func getInboundCallController(incoming applicationCall: ApplicationCall, establishedEvent: CallEstablishedEvent) -> MMCallController {
        let callController = MMCallController()
        applicationCall.applicationCallEventListener = callController.callEventListener
        callController.interactor.currentCall = .applicationCall(applicationCall)
        callController.callEventListener.onEstablished(establishedEvent)
        if let incomingCall = applicationCall as? IncomingApplicationCall {
            callController.uiState.remoteTitle = incomingCall.fromDisplayName ?? ""
            callController.uiState.isRemoteMuted = false
        }
        return callController
    }

    @MainActor
    func getInboundCallController(incoming webRTCCall: WebrtcCall, establishedEvent: CallEstablishedEvent) -> MMCallController {
        let callController = MMCallController()
        webRTCCall.webrtcCallEventListener = callController.callEventListener
        callController.callEventListener.onEstablished(establishedEvent)
        callController.interactor.currentCall = .webRTCCall(webRTCCall)
        if let webRTCCall = webRTCCall as? IncomingWebrtcCall {
            callController.uiState.remoteTitle = webRTCCall.destination().displayIdentifier() ?? webRTCCall.destination().identifier()
            callController.uiState.isRemoteMuted = false
        }
        return callController
    }
    
//    func getOutboundCallController(ongoing destination: String, from: String, destinationName: String?,
//                    conversationId: String?, callType: MMCallType = .pstn) -> MMCallController {
//        let callController = getNewCallController()
//        callController.counterpart = destination
//        callController.outboundFrom = from
//        callController.destinationName = destinationName
//        callController.outboundConversationId = conversationId
//        callController.callType = callType
//        return callController
//    }
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
#endif
