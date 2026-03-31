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

    func onRinging(_ callRingingEvent: CallRingingEvent) { }

    func onEarlyMedia(_ callEarlyMediaEvent: CallEarlyMediaEvent) { }

    func onEstablished(_ callEstablishedEvent: CallEstablishedEvent) {
        Task { @MainActor [weak self] in
            guard let currentCall = self?.controller?.interactor.currentCall else { return }
            self?.controller?.uiState.callPhase = .established
            self?.controller?.uiState.callType = .audio
            self?.controller?.startCallTimer()
            switch currentCall {
            case .applicationCall(let applicationCall):
                CallKitManager.shared.connectApplicationCall(applicationCall.id())
            case .webRTCCall(let webrtcCall):
                CallKitManager.shared.connectWebRTCCall(webrtcCall.id())
            }
        }
    }

    func onHangup(_ callHangupEvent: CallHangupEvent) {
        MMLogDebug("finalizeCallPreview with message: Status: \(callHangupEvent.errorCode.name)")
        controller?.hangup()
    }

    func onError(_ errorEvent: ErrorEvent) { }

    func onCameraVideoAdded(_ cameraVideoAddedEvent: CameraVideoAddedEvent) {
        Task { @MainActor [weak self] in
            self?.controller?.uiState.localVideoTrack = cameraVideoAddedEvent.track
        }
    }

    func onCameraVideoUpdated(_ cameraVideoUpdatedEvent: CameraVideoUpdatedEvent) {
        Task { @MainActor [weak self] in
            self?.controller?.uiState.localVideoTrack = cameraVideoUpdatedEvent.track
        }
    }

    func onCameraVideoRemoved() {
        Task { @MainActor [weak self] in
            self?.controller?.uiState.localVideoTrack = nil
        }
    }

    func onScreenShareAdded(_ screenShareAddedEvent: ScreenShareAddedEvent) {
        Task { @MainActor [weak self] in
            self?.controller?.uiState.screenshare = .local(screenShareAddedEvent.track)
        }
    }

    func onScreenShareRemoved(_ screenShareRemovedEvent: ScreenShareRemovedEvent) {
        Task { @MainActor [weak self] in
            self?.controller?.uiState.screenshare = .none
            self?.controller?.setButton(id: "screenshare", selected: false)
        }
    }

    func onRemoteMuted(_ event: ParticipantMutedEvent?) {
        Task { @MainActor [weak self] in
            self?.controller?.uiState.isRemoteMuted = true
        }
    }

    func onRemoteUnmuted(_ event: ParticipantUnmutedEvent?) {
        Task { @MainActor [weak self] in
            self?.controller?.uiState.isRemoteMuted = false
        }
    }

    func onRemoteCameraVideoAdded(_ videoTrack: VideoTrack, participant: Participant?) {
        Task { @MainActor [weak self] in
            self?.controller?.uiState.remoteVideoTrack = videoTrack
        }
    }

    func onRemoteCameraVideoRemoved(participant: Participant?) {
        Task { @MainActor [weak self] in
            self?.controller?.uiState.remoteVideoTrack = nil
        }
    }

    func onRemoteScreenShareAdded(_ videoTrack: VideoTrack, participant: Participant?) {
        Task { @MainActor [weak self] in
            self?.controller?.uiState.screenshare = .remote(videoTrack)
        }
    }

    func onRemoteScreenShareRemoved(participant: Participant?) {
        Task { @MainActor [weak self] in
            // Only clear if remote was active (don't overwrite a local screenshare)
            if case .remote = self?.controller?.uiState.screenshare {
                self?.controller?.uiState.screenshare = .none
            }
        }
    }

    func onReconnecting(_ callReconnectingEvent: CallReconnectingEvent) {
        Task { @MainActor [weak self] in
            self?.controller?.didStartReconnecting(true)
        }
    }

    func onReconnected(_ callReconnectedEvent: CallReconnectedEvent) {
        Task { @MainActor [weak self] in
            self?.controller?.didStartReconnecting(false)
        }
    }
}

@MainActor
class MMCallEventListener: @MainActor CallEventListener, @MainActor ApplicationCallEventListener, @MainActor WebrtcCallEventListener {
    func onTalkingWhileMuted(_ talkingWhileMuted: TalkingWhileMutedEvent) { }
    func onStartedTalking(_ startedTalkingEvent: StartedTalkingEvent) { }
    func onStoppedTalking(_ stoppedTalkingEvent: StoppedTalkingEvent) { }
    func onMessageReceived(_ messageReceivedEvent: MessageReceivedEvent) { }
    func onCameraVideoRemoved(_ cameraVideoRemovedEvent: CameraVideoRemovedEvent) {
        output.onCameraVideoRemoved()
    }
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

    // MARK: - Application Specific

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
    func onParticipantDisconnected(_ participantDisconnectedEvent: ParticipantDisconnectedEvent) { }
    func onParticipantReconnected(_ participantReconnectedEvent: ParticipantReconnectedEvent) { }
    func onRemoteDisconnected(_ remoteDisconnectedEvent: RemoteDisconnectedEvent) { }
    func onRemoteReconnected(_ remoteReconnectedEvent: RemoteReconnectedEvent) { }
}

protocol AggregatedCallEventListener {
    func onRinging(_ callRingingEvent: CallRingingEvent)
    func onEarlyMedia(_ callEarlyMediaEvent: CallEarlyMediaEvent)
    func onEstablished(_ callEstablishedEvent: CallEstablishedEvent)
    func onHangup(_ callHangupEvent: CallHangupEvent)
    func onError(_ errorEvent: ErrorEvent)
    func onCameraVideoAdded(_ cameraVideoAddedEvent: CameraVideoAddedEvent)
    func onCameraVideoUpdated(_ cameraVideoUpdatedEvent: CameraVideoUpdatedEvent)
    func onCameraVideoRemoved()
    func onScreenShareAdded(_ screenShareAddedEvent: ScreenShareAddedEvent)
    func onScreenShareRemoved(_ screenShareRemovedEvent: ScreenShareRemovedEvent)
    func onRemoteMuted(_ event: ParticipantMutedEvent?)
    func onRemoteUnmuted(_ event: ParticipantUnmutedEvent?)
    func onRemoteCameraVideoAdded(_ videoTrack: VideoTrack, participant: Participant?)
    func onRemoteCameraVideoRemoved(participant: Participant?)
    func onRemoteScreenShareAdded(_ videoTrack: VideoTrack, participant: Participant?)
    func onRemoteScreenShareRemoved(participant: Participant?)
    func onReconnecting(_ callReconnectingEvent: CallReconnectingEvent)
    func onReconnected(_ callReconnectedEvent: CallReconnectedEvent)
}
#endif
