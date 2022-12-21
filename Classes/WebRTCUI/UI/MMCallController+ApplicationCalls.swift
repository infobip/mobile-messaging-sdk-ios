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
    public func onParticipantMuted(participantMutedEvent: ParticipantMutedEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        participantMutedImageV.isHidden = false
    }
    
    public func onParticipantUnmuted(participantUnmutedEvent: ParticipantUnmutedEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        participantMutedImageV.isHidden = true
    }
    
    public func onParticipantDeaf(participantDeafEvent: ParticipantDeafEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        // Not supported yet
    }
    
    public func onParticipantUndeaf(participantUndeafEvent: ParticipantUndeafEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        // Not supported yet
    }
    
    public func onParticipantStartedTalking(participantStartedTalkingEvent: ParticipantStartedTalkingEvent) {
        // Not supported yet
    }
    
    public func onParticipantStoppedTalking(participantStoppedTalkingEvent: ParticipantStoppedTalkingEvent) {
        // Not supported yet
    }
    
    public func onError(error: ErrorEvent) {
        if activeApplicationCall != nil {
            onApplicationError(error.errorCode.description)
        }
    }
    
    public func onCameraVideoAdded(cameraVideoAddedEvent: CameraVideoAddedEvent) {
        established(localVideoTrack: cameraVideoAddedEvent.track)
    }
    
    public func onCameraVideoUpdated(cameraVideoUpdatedEvent: CameraVideoUpdatedEvent) {
        updated(localVideoTrack: cameraVideoUpdatedEvent.track)
    }
    
    public func onCameraVideoRemoved() {
        localVideoView.isHidden = true
        showActiveCallViewElements()
    }
    
    public func onScreenShareAdded(screenShareAddedEvent: ScreenShareAddedEvent) {
        // Handle by the controller. Only feedback is button in selected state
    }
    
    public func onScreenShareRemoved() {
        // Handle by the controller. Only feedback is button in unselected state
    }
    
    public func onParticipantCameraVideoAdded(participantCameraVideoAddedEvent: ParticipantCameraVideoAddedEvent) {
        if remoteSharingVideoTrack == nil {
            // Screen sharing has priority over camera streaming, and will never be replaced while ongoing.
            participantVideoAdded(videoTrack: participantCameraVideoAddedEvent.videoTrack)
        }
        remoteCameraVideoTrack = participantCameraVideoAddedEvent.videoTrack
    }
    
    public func onParticipantCameraVideoRemoved(participantCameraVideoRemovedEvent: ParticipantCameraVideoRemovedEvent) {
        remoteCameraVideoTrack = nil
        participantVideoRemoved()
    }
    
    public func onParticipantScreenShareAdded(participantScreenShareAddedEvent: ParticipantScreenShareAddedEvent) {
        if remoteCameraVideoTrack != nil {
            remoteView?.removeFromSuperview()
        }
        participantVideoAdded(videoTrack: participantScreenShareAddedEvent.videoTrack)
        remoteSharingVideoTrack = participantScreenShareAddedEvent.videoTrack
    }
    
    public func onParticipantScreenShareRemoved(participantScreenShareRemovedEvent: ParticipantScreenShareRemovedEvent) {
        remoteSharingVideoTrack = nil
        participantVideoRemoved()
    }
    
    public func onConferenceJoined(conferenceJoinedEvent: ConferenceJoinedEvent) {
        joined = true
        conferenceParticipants = conferenceJoinedEvent.participants
        // Not supported yet
    }
    
    public func onConferenceLeft(conferenceLeftEvent: ConferenceLeftEvent) {
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
    
    public func onParticipantJoining(participantJoiningEvent: ParticipantJoiningEvent) {
        conferenceParticipants.append(participantJoiningEvent.participant)
        // Not supported yet
    }
    
    public func onParticipantJoined(participantJoinedEvent: ParticipantJoinedEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        // Not supported yet
    }
    
    public func onParticipantLeft(participantLeftEvent: ParticipantLeftEvent) {
        conferenceParticipants = activeApplicationCall?.participants() ?? []
        // Not supported yet
    }
    
    func isVideoApplicationCall() -> Bool {
        return activeApplicationCall != nil &&
        (activeApplicationCall!.hasCameraVideo() ||
         activeApplicationCall!.hasScreenShare() ||
         hasApplicationRemoteVideo())
    }
    
    func hasApplicationRemoteVideo() -> Bool {
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
    
    private func finishApplicationCall() {
        guard let activeApplicationCall = activeApplicationCall else { return }
        CallKitManager.shared.endApplicationCall(activeApplicationCall)
        finalizeCallPreview("Did finishApplicationCall")
    }
}
