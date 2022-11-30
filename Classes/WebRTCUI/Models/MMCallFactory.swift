//
//  MMCallFactory.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 19/08/2021.
//  Copyright © 2021 Infobip Ltd. All rights reserved.
//

import InfobipRTC

public struct MMWebRTCUIConstants {
    static let phoneNumber = "phoneNumber"
    static let autoAccept = "autoAccept"
    static let clientType = "clientType"
    static let pstn = "PSTN"
    static let webrtc = "WEBRTC"
    static let source = "source"
    static let displayName = "displayName"
    static let isOutbound = "isOutbound"
    static let isVideo = "isVideo"
    static let margin = 8.0
}

extension Int {
    var mmLocalisedCallErrorEvent: String? {
        switch self {
        case 5503, 5902, 5907: //EC_SERVICE_UNAVAILABLE, EC_INTERNAL_SERVER_ERROR, EC_TEMPORARILY_NOT_AVAILABLE
            return MMLoc.callsUsageError
        case 5801: // EC_USER_BUSY
            return MMLoc.userBusy
        case 5803, 5804, 5903, 5906: // EC_DEVICE_NOT_FOUND, EC_DEVICE_NOT_AVAILABLE,
            //EC_ERROR_DESTINATION_NOT_FOUND
            return MMLoc.userNotFoundDestination
        case 5603: // EC_DECLINE
            return MMLoc.userDeclinedCall
        case 5991: // EC_UNKNOWN_WEBRTC_ERROR, EC_CONNECTION_ERROR
            return MMLoc.somethingWentWrongPleaseContactSupport
        default:
            return nil
        }
    }
}

class MMCallFactory {
    static func create(_ callRequest: CallRequest, 
                       _ callType: MMCallType,
                       _ recording: Bool, 
                       _ from: String?) throws -> Call {
        switch callType {
        case .pstn:
            return try InfobipRTC.callPhoneNumber(
                callRequest, 
                CallPhoneNumberOptions(from: from, RecordingOptions(recording, false)))
        case .video:
            return try InfobipRTC.call(
                callRequest, 
                CallOptions(video: true, recordingOptions: RecordingOptions(recording, recording)))
        case .conversationsAudio:
            guard let request = callRequest as? CallConversationsRequest else {
                throw CallError.invalidCustomData
            }
            return try InfobipRTC.callConversations(request)
        case .conversationsVideo:
            guard let request = callRequest as? CallConversationsRequest else {
                throw CallError.invalidCustomData
            }
            return try InfobipRTC.callConversations(request, CallOptions(video: true))
        case .sipAudio:
            return try InfobipRTC.callSIP(callRequest)
        case .sipVideo:
            return try InfobipRTC.callSIP(
                callRequest, 
                CallOptions(video: true))
        default:
            return try InfobipRTC.call(
                callRequest, 
                CallOptions(video: false, recordingOptions: RecordingOptions(recording, false)))
        }
    }
    
    static func createApplicationCall(_ callApplicationRequest: CallApplicationRequest,
                                      _ callType: MMCallType,
                                      _ isMuted: Bool) throws -> ApplicationCall {
        switch callType {
        case .application_video:
            return try InfobipRTC.callApplication(callApplicationRequest, CallOptions(audio: !isMuted, video: true))
        default:
            return try InfobipRTC.callApplication(callApplicationRequest, CallOptions(audio: !isMuted, video: false))
        }
    }
}

public enum MMCallType {
    case pstn
    case audio
    case video
    case conversationsAudio
    case conversationsVideo
    case conferenceAudio
    case conferenceVideo
    case application_audio
    case application_video
    case sipAudio
    case sipVideo
}
