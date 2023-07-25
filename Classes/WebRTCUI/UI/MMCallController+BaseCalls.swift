//
//  MMCallController+BaseCalls.swift
//  MobileMessaging
//
//  Created by Maksym Svitlovskyi on 28/03/2023.
//  Copyright © 2023 Infobip Ltd. All rights reserved.
//

import Foundation
#if WEBRTCUI_ENABLED
import InfobipRTC
// MARK: - Common delegate methods for ApplicationCall & WebRTC Call
extension MMCallController {
    public func onRinging(_ callRingingEvent: CallRingingEvent) {
        ringing(callType: self.callType)
    }

    public func onEarlyMedia(_ callEarlyMediaEvent: CallEarlyMediaEvent) {
        self.stopRingback()
        self.callStatusLabel.text = MMLoc.notificationRinging
    }

    public func onEstablished(_ callEstablishedEvent: CallEstablishedEvent) {
        self.callEstablishedEvent = callEstablishedEvent
        self.startCallDuration()

        if let activeCall = activeCall {
            self.established(call: activeCall)
            switch activeCall {
            case .applicationCall(let applicationCall):
                CallKitManager.shared.connectApplicationCall(applicationCall.id())
                if callType == .application_video {
                    // If call is (inbound) application video, we need to manually start local video
                    toggleVideo(videoStatusBottomView.localVideo)
                }
            case .webRTCCall(let webRTCCall):
                CallKitManager.shared.connectWebRTCCall(webRTCCall.id())
                if callType == .application_video {
                    // If call is (inbound) application video, we need to manually start local video
                    toggleVideo(videoStatusBottomView.localVideo)
                }
            }
        }
    }

    public func onHangup(_ callHangupEvent: CallHangupEvent) {
        let errorCode = callHangupEvent.errorCode
        hangup(errorCodeName: errorCode.name)
    }

    public func onError(_ errorEvent: ErrorEvent) {
        if activeApplicationCall != nil {
            onApplicationError(errorEvent.errorCode.description)
        } else {
            showErrorAlert(message: errorEvent.errorCode.description)
        }
    }

    public func onCameraVideoAdded(_ cameraVideoAddedEvent: CameraVideoAddedEvent) {
        established(localVideoTrack: cameraVideoAddedEvent.track)
    }

    public func onCameraVideoUpdated(_ cameraVideoUpdatedEvent: CameraVideoUpdatedEvent) {
        updated(localVideoTrack: cameraVideoUpdatedEvent.track)
    }

    public func onCameraVideoRemoved() {
        localVideoView.isHidden = true
        showActiveCallViewElements()
    }

    public func onScreenShareAdded(_ screenShareAddedEvent: ScreenShareAddedEvent) {
        // Not supported, test from portal/webrtc demo
    }

    public func onScreenShareRemoved() {
        // Not supported
    }

    // MARK: - Common methods for handling remote media for Application Call & WebRTC Call

    func handleRemoteTrackAdded( _ track: VideoTrack, isScreensharing: Bool) {
        if activeCallTracks.isAnyVideoTrack { remoteView?.removeFromSuperview() }
        activeCallTracks.add(track: track, isScreensharing: isScreensharing)
        participantVideoAdded(videoTrack: track)
    }

    func handleRemoteTrackRemoved(isScreensharing: Bool) {
        remoteView?.removeFromSuperview()
        if let newActiveVideoTrack = activeCallTracks.remove(isScreensharing: isScreensharing) {
            participantVideoAdded(videoTrack: newActiveVideoTrack)
        } else {
            self.showVideoElements()
            self.counterpartImage.isHidden = false
        }
    }

    private func participantVideoAdded(videoTrack: VideoTrack) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        established(remoteVideoTrack: videoTrack)
    }
}
#endif
