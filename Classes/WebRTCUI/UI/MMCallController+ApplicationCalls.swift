//
//  MMCallController+ApplicationCalls.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 22/06/2022.
//  Copyright © 2022 Infobip Ltd. All rights reserved.
//

import UIKit
import InfobipRTC
import AVFoundation
import CallKit
import os.log

extension UIViewController {
    func mmDismissAllModals(animated flag: Bool, completion: (() -> Void)? = nil) {
        if presentedViewController != nil {
            presentedViewController?.mmDismissAllModals(animated: flag) {
                self.dismiss(animated: flag, completion: completion)
            }
        } else {
            self.dismiss(animated: flag) {
                completion?()
            }
        }
    }
}

extension MMCallController: ApplicationCallEventListener {
    public func onRinging(_ callRingingEvent: CallRingingEvent) {
        ringing(callType: self.callType)
    }

    public func onEarlyMedia(_ callEarlyMediaEvent: CallEarlyMediaEvent) {
        self.stopRingback()
        self.callStatusLabel.text = MMLoc.notificationRinging
    }
    
    public func onEstablished(_ callEstablishedEvent: CallEstablishedEvent) {
        self.callEstablishedEvent = callEstablishedEvent
        established(callEstablishedEvent: callEstablishedEvent)
        self.startCallDuration()
        if let appCall = self.activeApplicationCall {
            CallKitManager.shared.connectApplicationCall(appCall.id())
            if callType == .application_video {
                // If call is (inbound) application video, we need to manually start local video
                toggleVideo(videoStatusBottomView.localVideo)
            }
        }
    }

    public func onHangup(_ callHangupEvent: CallHangupEvent) {
        let errorCode = callHangupEvent.errorCode
        hangup(errorCodeName: errorCode.name)
    }

    public func onParticipantMuted(_ participantMutedEvent: ParticipantMutedEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        participantMutedImageV.isHidden = false
    }

    public func onParticipantUnmuted(_ participantUnmutedEvent: ParticipantUnmutedEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        participantMutedImageV.isHidden = true
    }

    public func onParticipantDeaf(_ participantDeafEvent: ParticipantDeafEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        // Not supported yet
    }

    public func onParticipantUndeaf(_ participantUndeafEvent: ParticipantUndeafEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        // Not supported yet
    }

    public func onParticipantStartedTalking(_ participantStartedTalkingEvent: ParticipantStartedTalkingEvent) {
        // Not supported yet
    }

    public func onParticipantStoppedTalking(_ participantStoppedTalkingEvent: ParticipantStoppedTalkingEvent) {
        // Not supported yet
    }

    public func onError(_ errorEvent: ErrorEvent) {
        if activeApplicationCall != nil {
            onApplicationError(errorEvent.errorCode.description)
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

    public func onParticipantCameraVideoAdded(_ participantCameraVideoAddedEvent: ParticipantCameraVideoAddedEvent) {
        handleRemoteTrackAdded(participantCameraVideoAddedEvent.track)
    }

    public func onParticipantCameraVideoRemoved(_ participantCameraVideoRemovedEvent: ParticipantCameraVideoRemovedEvent) {
        handleRemoteTrackRemoved()
    }

    public func onParticipantScreenShareAdded(_ participantScreenShareAddedEvent: ParticipantScreenShareAddedEvent) {
        handleRemoteTrackAdded(participantScreenShareAddedEvent.track)
    }

    public func onParticipantScreenShareRemoved(_ participantScreenShareRemovedEvent: ParticipantScreenShareRemovedEvent) {
        handleRemoteTrackRemoved()
    }

    private func handleRemoteTrackAdded( _ track: VideoTrack) {
        if remoteCameraVideoTrack != nil {
            remoteView?.removeFromSuperview()
        }
        participantVideoAdded(videoTrack: track)
        remoteSharingVideoTrack = track
    }

    private func handleRemoteTrackRemoved() {
        remoteSharingVideoTrack = nil
        participantVideoRemoved()
    }

    public func onConferenceJoined(_ conferenceJoinedEvent: ConferenceJoinedEvent) {
        joined = true
        conferenceParticipants = conferenceJoinedEvent.participants
        if let participant = conferenceParticipants.filter({ $0.state == .JOINING }).last {
            participantMutedImageV.isHidden = !(participant.media?.audio.muted ?? false)
        }
    }

    public func onConferenceLeft(_ conferenceLeftEvent: ConferenceLeftEvent) {
        joined = false
        if let incomingApplicationCall = activeApplicationCall as? IncomingApplicationCall {
            counterpart = incomingApplicationCall.from
        } else {
            counterpart = activeApplicationCall?.applicationId()
        }
        counterpartLabel.text = counterpart
        conferenceParticipants = []
        participantVideoRemoved()
    }

    public func onParticipantJoining(_ participantJoiningEvent: ParticipantJoiningEvent) {
        conferenceParticipants.append(participantJoiningEvent.participant)
        // Not supported yet
    }

    public func onParticipantJoined(_ participantJoinedEvent: ParticipantJoinedEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        // Not supported yet
    }

    public func onParticipantLeft(_ participantLeftEvent: ParticipantLeftEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        // Not supported yet
    }

    public func isVideoApplicationCall() -> Bool {
        return activeApplicationCall != nil &&
        (activeApplicationCall!.hasCameraVideo() ||
         activeApplicationCall!.hasScreenShare() ||
         hasApplicationRemoteVideo())
    }

    public func hasApplicationRemoteVideo() -> Bool {
        return !activeApplicationCall!.remoteVideos().isEmpty
    }

    private func participantVideoAdded(videoTrack: VideoTrack) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        established(remoteVideoTrack: videoTrack)
    }

    private func participantVideoRemoved() {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        remoteView?.removeFromSuperview()
        counterpartImage.isHidden = false
        remoteView?.isHidden = true
        if let secondaryVideoTrack = remoteCameraVideoTrack ?? remoteSharingVideoTrack {
            // We recover a video track that may have been waiting to be presented.
            participantVideoAdded(videoTrack: secondaryVideoTrack)
        } else {
            self.counterpartImage.isHidden = false
        }
    }

    private func onApplicationError(_ error: String) {
        if activeApplicationCall != nil {
            showErrorAlert(message: error)
        }
    }
}
