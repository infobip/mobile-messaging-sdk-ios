//
//  MMCallController+ApplicationCalls.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 22/06/2022.
//  Copyright © 2022 Infobip Ltd. All rights reserved.
//
import UIKit
#if WEBRTCUI_ENABLED
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

    var activeApplicationCall: ApplicationCall? {
        switch activeCall {
        case .applicationCall(let applicationCall):
            return applicationCall
        default: return nil
        }
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

    public func onParticipantCameraVideoAdded(_ participantCameraVideoAddedEvent: ParticipantCameraVideoAddedEvent) {
        handleRemoteTrackAdded(participantCameraVideoAddedEvent.track, isScreensharing: false)
    }

    public func onParticipantCameraVideoRemoved(_ participantCameraVideoRemovedEvent: ParticipantCameraVideoRemovedEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        handleRemoteTrackRemoved(isScreensharing: false)
    }

    public func onParticipantScreenShareAdded(_ participantScreenShareAddedEvent: ParticipantScreenShareAddedEvent) {
        handleRemoteTrackAdded(participantScreenShareAddedEvent.track, isScreensharing: true)
    }

    public func onParticipantScreenShareRemoved(_ participantScreenShareRemovedEvent: ParticipantScreenShareRemovedEvent) {
        handleRemoteTrackRemoved(isScreensharing: true)
    }

    public func onConferenceJoined(_ conferenceJoinedEvent: ConferenceJoinedEvent) {
        joined = true
        conferenceParticipants = conferenceJoinedEvent.participants
        setMutedParticipant()
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
        remoteView?.removeFromSuperview()
    }

    public func onParticipantJoining(_ participantJoiningEvent: ParticipantJoiningEvent) {
        conferenceParticipants.append(participantJoiningEvent.participant)
        setMutedParticipant()
    }

    public func onParticipantJoined(_ participantJoinedEvent: ParticipantJoinedEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        setMutedParticipant()
    }

    private func setMutedParticipant() {
        participantMutedImageV.isHidden = conferenceParticipants.filter({
            return $0.endpoint.identifier() != MobileMessaging.currentInstallation?.pushRegistrationId &&
            $0.media.audio.muted}
        ).isEmpty
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

    func onApplicationError(_ error: String) {
        if activeApplicationCall != nil {
            showErrorAlert(message: error)
        }
    }
}
#endif
