// 
//  MMCallEventListener.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
#if WEBRTCUI_ENABLED
import InfobipRTC

class CallControllerEventListenerImpl: AggregatedCallEventListener {
    
    weak var controller: MMCallController?
    
    init(controller: MMCallController) {
        self.controller = controller
    }
    
    func onRinging(_ callRingingEvent: CallRingingEvent) {  }
    
    func onEarlyMedia(_ callEarlyMediaEvent: CallEarlyMediaEvent) { }
    
    func onEstablished(_ callEstablishedEvent: CallEstablishedEvent) {
        
        guard let currentCall = controller?.interactor.currentCall else { return }
        
        controller?.callView.updateState(with: .audioCall) /// TODO: connect video
        
        switch currentCall {
        case .applicationCall(let applicationCall):
            CallKitManager.shared.connectApplicationCall(applicationCall.id())
        case .webRTCCall(let webrtcCall):
            CallKitManager.shared.connectWebRTCCall(webrtcCall.id())
        }
    }
    
    func onHangup(_ callHangupEvent: CallHangupEvent) {
        MMLogDebug("finalizeCallPreview with message: Status: \(callHangupEvent.errorCode.name)")
        controller?.hangup()
    }
    
    func onError(_ errorEvent: ErrorEvent) {
        // Error callback
    }
    
    func onCameraVideoAdded(_ cameraVideoAddedEvent: CameraVideoAddedEvent) {
        controller?.callView.updateState(updateMedia: .localVideo(cameraVideoAddedEvent.track))
    }
    
    func onCameraVideoUpdated(_ cameraVideoUpdatedEvent: CameraVideoUpdatedEvent) {
        controller?.callView.updateState(updateMedia: .localVideo(cameraVideoUpdatedEvent.track))
    }
    
    func onCameraVideoRemoved() {
        controller?.callView.updateState(updateMedia: .localVideo(nil))
    }
    
    func onScreenShareAdded(_ screenShareAddedEvent: ScreenShareAddedEvent) {
        controller?.callView.updateState(updateMedia: .localScreenshare(screenShareAddedEvent.track))
    }
    
    func onScreenShareRemoved(_ screenShareRemovedEvent: ScreenShareRemovedEvent) {
        controller?.callView.updateState(updateMedia: .localScreenshare(nil))
        controller?.screenshareButtonContent?.button?.isSelected = false
    }
    
    func onRemoteMuted(_ event: ParticipantMutedEvent?) {
        controller?.callView.updateState(remoteMuted: true)
    }
    
    func onRemoteUnmuted(_ event: ParticipantUnmutedEvent?) {
        controller?.callView.updateState(remoteMuted: false)
    }
    
    func onRemoteCameraVideoAdded(_ videoTrack: VideoTrack, participant: Participant?) {
        controller?.callView.updateState(updateMedia: .remoteVideo(videoTrack))
    }
    
    func onRemoteCameraVideoRemoved(participant: Participant?) {
        controller?.callView.updateState(updateMedia: .remoteVideo(nil))
    }
    
    func onRemoteScreenShareAdded(_ videoTrack: VideoTrack, participant: Participant?) {
        controller?.callView.updateState(updateMedia: .remoteScreenshare(videoTrack))
    }
    
    func onRemoteScreenShareRemoved(participant: Participant?) {
        controller?.callView.updateState(updateMedia: .remoteScreenshare(nil))
    }
    
    func onReconnecting(_ callReconnectingEvent: CallReconnectingEvent) {
        controller?.didStartReconnecting(true)
    }
    
    func onReconnected(_ callReconnectedEvent: CallReconnectedEvent) {
        controller?.didStartReconnecting(false)
    }
}
 
class MMCallEventListener: CallEventListener, ApplicationCallEventListener, WebrtcCallEventListener {
    func onTalkingWhileMuted(_ talkingWhileMuted: TalkingWhileMutedEvent) { }
    
    func onStartedTalking(_ startedTalkingEvent: StartedTalkingEvent) { }
    
    func onStoppedTalking(_ stoppedTalkingEvent: StoppedTalkingEvent) { }
    
    func onMessageReceived(_ messageReceivedEvent: MessageReceivedEvent) { }
    
    func onCameraVideoRemoved(_ cameraVideoRemovedEvent: CameraVideoRemovedEvent) { }

    func onParticipantBlinded(_ participantBlindedEvent: ParticipantBlindedEvent) { }

    func onParticipantUnblinded(_ participantUnblindedEvent: ParticipantUnblindedEvent) { }

    func onRoleChanged(_ roleChangedEvent: RoleChangedEvent) { }

    func onParticipantRoleChanged(_ participantRoleChangedEvent: ParticipantRoleChangedEvent) { }

    let output: AggregatedCallEventListener
    
    init(controller: AggregatedCallEventListener) {
        self.output = controller
    }
    // MARK: - Base call Event Listener
    func onCameraVideoAdded(_ cameraVideoAddedEvent: CameraVideoAddedEvent) {
        output.onCameraVideoAdded(cameraVideoAddedEvent)
    }
    
    func onCameraVideoUpdated(_ cameraVideoUpdatedEvent: CameraVideoUpdatedEvent) {
        output.onCameraVideoUpdated(cameraVideoUpdatedEvent)
    }
    
    func onCameraVideoRemoved() {
        output.onCameraVideoRemoved()
    }
    
    func onScreenShareAdded(_ screenShareAddedEvent: ScreenShareAddedEvent) {
        output.onScreenShareAdded(screenShareAddedEvent)
    }
    
    func onScreenShareRemoved(_ screenShareRemovedEvent: ScreenShareRemovedEvent) {
        output.onScreenShareRemoved(screenShareRemovedEvent)
    }

    func onRinging(_ callRingingEvent: CallRingingEvent) {
        output.onRinging(callRingingEvent)
    }
    
    func onEarlyMedia(_ callEarlyMediaEvent: CallEarlyMediaEvent) {
        output.onEarlyMedia(callEarlyMediaEvent)
    }
    
    func onEstablished(_ callEstablishedEvent: CallEstablishedEvent) {
        output.onEstablished(callEstablishedEvent)
    }
    
    func onHangup(_ callHangupEvent: CallHangupEvent) {
        output.onHangup(callHangupEvent)
    }
    
    func onError(_ errorEvent: ErrorEvent) { 
        output.onError(errorEvent)
    }
    
    func onReconnecting(_ callReconnectingEvent: CallReconnectingEvent) {
        output.onReconnecting(callReconnectingEvent)
    }

    func onReconnected(_ callReconnectedEvent: CallReconnectedEvent) {
        output.onReconnected(callReconnectedEvent)
    }
    // MARK: - WebrtcCallEventListener
    func onRemoteCameraVideoAdded(_ cameraVideoAddedEvent: CameraVideoAddedEvent) {
        output.onRemoteCameraVideoAdded(cameraVideoAddedEvent.track, participant: nil)
    }
    
    func onRemoteCameraVideoRemoved() { 
        output.onRemoteCameraVideoRemoved(participant: nil)
    }
    
    func onRemoteScreenShareAdded(_ screenShareAddedEvent: ScreenShareAddedEvent) {
        output.onRemoteScreenShareAdded(screenShareAddedEvent.track, participant: nil)
    }
    
    func onRemoteScreenShareRemoved() { 
        output.onRemoteScreenShareRemoved(participant: nil)
    }
    
    func onRemoteMuted() { 
        output.onRemoteMuted(nil)
    }
    
    func onRemoteUnmuted() {
        output.onRemoteUnmuted(nil)
    }
    // MARK: Application Specific
    // Remote camera
    func onParticipantCameraVideoAdded(_ participantCameraVideoAddedEvent: ParticipantCameraVideoAddedEvent) {
        output.onRemoteCameraVideoAdded(participantCameraVideoAddedEvent.track, participant: participantCameraVideoAddedEvent.participant)
    }
    
    func onParticipantCameraVideoRemoved(_ participantCameraVideoRemovedEvent: ParticipantCameraVideoRemovedEvent) {
        output.onRemoteCameraVideoRemoved(participant: participantCameraVideoRemovedEvent.participant)
    }
    
    func onParticipantScreenShareAdded(_ participantScreenShareAddedEvent: ParticipantScreenShareAddedEvent) {
        output.onRemoteScreenShareAdded(participantScreenShareAddedEvent.track, participant: participantScreenShareAddedEvent.participant)
    }
    
    func onParticipantScreenShareRemoved(_ participantScreenShareRemovedEvent: ParticipantScreenShareRemovedEvent) {
        output.onRemoteScreenShareRemoved(participant: participantScreenShareRemovedEvent.participant)
    }
    
    func onParticipantMuted(_ participantMutedEvent: ParticipantMutedEvent) {
        output.onRemoteMuted(participantMutedEvent)
    }
    
    func onParticipantUnmuted(_ participantUnmutedEvent: ParticipantUnmutedEvent) {
        output.onRemoteUnmuted(participantUnmutedEvent)
    }
    // Not used
    func onConferenceJoined(_ conferenceJoinedEvent: ConferenceJoinedEvent) { }
    
    func onConferenceLeft(_ conferenceLeftEvent: ConferenceLeftEvent) { }
    
    func onParticipantJoining(_ participantJoiningEvent: ParticipantJoiningEvent) { }
    
    func onParticipantJoined(_ participantJoinedEvent: ParticipantJoinedEvent) { }
    
    func onParticipantLeft(_ participantLeftEvent: ParticipantLeftEvent) { }

    func onParticipantDeaf(_ participantDeafEvent: ParticipantDeafEvent) { }
    
    func onParticipantUndeaf(_ participantUndeafEvent: ParticipantUndeafEvent) { }
    
    func onParticipantStartedTalking(_ participantStartedTalkingEvent: ParticipantStartedTalkingEvent) { }
    
    func onParticipantStoppedTalking(_ participantStoppedTalkingEvent: ParticipantStoppedTalkingEvent) { }
    
    func onDialogJoined(_ dialogJoinedEvent: DialogJoinedEvent) { }
    
    func onDialogLeft(_ dialogLeftEvent: DialogLeftEvent) { }

    @objc func onCallRecordingStarted(_ callRecordingStartedEvent: CallRecordingStartedEvent) { }

    @objc func onCallRecordingStopped(_ callRecordingStoppedEvent: CallRecordingStoppedEvent) { }


    @objc func onDialogRecordingStarted(_ dialogRecordingStartedEvent: DialogRecordingStartedEvent) { }


    @objc func onDialogRecordingStopped(_ dialogRecordingStoppedEvent: DialogRecordingStoppedEvent) { }


    @objc func onConferenceRecordingStarted(_ conferenceRecordingStartedEvent: ConferenceRecordingStartedEvent) { }

    @objc func onConferenceRecordingStopped(_ conferenceRecordingStoppedEvent: ConferenceRecordingStoppedEvent) { }
    
    func onParticipantDisconnected(_ participantDisconnectedEvent:  ParticipantDisconnectedEvent) { }
    
    func onParticipantReconnected(_ participantReconnectedEvent: ParticipantReconnectedEvent) { }
    
    func onRemoteDisconnected(_ remoteDisconnectedEvent: RemoteDisconnectedEvent) { }
    
    func onRemoteReconnected(_ remoteReconnectedEvent: RemoteReconnectedEvent) { }
}

protocol AggregatedCallEventListener {
    // MARK: - Base call
    func onRinging(_ callRingingEvent: CallRingingEvent)
    
    func onEarlyMedia(_ callEarlyMediaEvent: CallEarlyMediaEvent)
    
    func onEstablished(_ callEstablishedEvent: CallEstablishedEvent)
    
    func onHangup(_ callHangupEvent: CallHangupEvent)
    
    func onError(_ errorEvent: ErrorEvent)
    
    
    // MARK: - Common naming
    func onCameraVideoAdded(_ cameraVideoAddedEvent: CameraVideoAddedEvent)
    
    func onCameraVideoUpdated(_ cameraVideoUpdatedEvent: CameraVideoUpdatedEvent)
    
    func onCameraVideoRemoved()
    
    func onScreenShareAdded(_ screenShareAddedEvent: ScreenShareAddedEvent)
    
    func onScreenShareRemoved(_ screenShareRemovedEvent: ScreenShareRemovedEvent)
    // MARK: Facaded
    /// Event only for application calls
    func onRemoteMuted(_ event: ParticipantMutedEvent?)
    /// Event only for application calls
    func onRemoteUnmuted(_ event: ParticipantUnmutedEvent?)
    
    func onRemoteCameraVideoAdded(_ videoTrack: VideoTrack, participant: Participant?)
    
    func onRemoteCameraVideoRemoved(participant: Participant?)
    
    func onRemoteScreenShareAdded(_ videoTrack: VideoTrack, participant: Participant?)
    
    func onRemoteScreenShareRemoved(participant: Participant?)
    
    func onReconnecting(_ callReconnectingEvent: CallReconnectingEvent)
    
    func onReconnected(_ callReconnectedEvent: CallReconnectedEvent)
}
#endif
