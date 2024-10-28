//
//  MMWebRTCService+Push.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 14.10.2022.
//
import Foundation
import WebKit
import CallKit
import PushKit
import AVFoundation
#if WEBRTCUI_ENABLED
import InfobipRTC

extension MMWebRTCService: PKPushRegistryDelegate {
    func createCallsPushRegistry() {
        guard isCallKitSupported() else {
            delegate?.callRegistrationEnded(with: .callsNotSupportedError, and: nil)
            return
        }
        let voipRegistry = PKPushRegistry(queue: q)
        voipRegistry.desiredPushTypes = [PKPushType.voIP]
        voipRegistry.delegate = self
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        if type == .voIP, isCallKitSupported() {
            useCallPushCredentials(pushCredentials)
        }
    }
    
    private func requestCallPushEnabling(with token: String, isRetry: Bool = false) {
        guard let pushCreds = notificationData?.pushPKCredentials,
              let webRTCConfigId = MMWebRTCService.sharedInstance?.configurationId else { return }
        var isDebugging = false
        // isDebugging flag will determine if the WebRTC calls use Production of Sandboxing modes/certificates
        #if DEBUG
            isDebugging = true
        #endif

        getInfobipRTCInstance().enablePushNotification(
            token,
            pushCredentials: pushCreds,
            debug: isDebugging,
            pushConfigId: webRTCConfigId) { [weak self] result in
            switch result.status {
            case .failure:
                MMLogDebug("Failure: can't obtain WebRTC regitration Token")
                self?.isRegistered = false
                if isRetry {
                    self?.delegate?.callRegistrationEnded(with: .registeringForCallsError, and: nil)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: { // we retry once
                        self?.requestCallPushEnabling(with: token, isRetry: true)
                    })
                }
            default:
                MMLogDebug("WebRTC regitration Token obtained successfully: \(token)")
                guard let `self` = self else { return }
                self.isRegistered = true
                self.delegate?.callRegistrationEnded(with: .success, and: nil)
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil)
            }
        }
    }
    
    private func handleRemoteCallPushRequest(enabling: Bool = false, completion: ((Bool) -> Void)? = nil) {
        MMWebRTCToken.obtain(queue: q, completion: { [weak self] result in
            var statusCode: MMWebRTCRegistrationCode?
            var statusError: Error?
            switch result {
            case .Failure(let error):
                MMLogError(error?.localizedDescription ?? "Unknown error in  MMWebRTCToken.obtain")
                statusCode = .gettingTokenError
                statusError = error
            case .Success(let response):
                if enabling {
                    self?.requestCallPushEnabling(with: response.token)
                } else { // otherwise we want to stop calls
                    getInfobipRTCInstance().disablePushNotification(response.token)
                    MMLogDebug("disableCallPushCredentials successfully called")
                    statusCode = .success
                    self?.isRegistered = false
                }
            case .Cancel:
                MMLogWarn(" MMWebRTCToken.obtain request cancelled.")
                statusCode = .gettingTokenError
            }
            completion?(statusCode == .success)
            guard let statusCode = statusCode else { return }
            if enabling {
                self?.delegate?.callRegistrationEnded(with: statusCode, and: statusError)
            } else {
                self?.delegate?.callUnregistrationEnded(with: statusCode, and: statusError)
            }
        })
    }
    
    public func useCallPushCredentials(_ pushCredentials: PKPushCredentials) {
        if notificationData == nil { notificationData = MMWebRTCNotificationData() }
        notificationData?.pushPKCredentials = pushCredentials
        guard MobileMessaging.currentInstallation?.pushRegistrationId != nil,
              identity != nil,
              !isRegistered else { return }
        handleRemoteCallPushRequest(enabling: true)
    }
    
    public func disableCallPushCredentials(_ completion: ((Bool) -> Void)? = nil) {
        handleRemoteCallPushRequest(enabling: false, completion: completion)
    }
        
    public func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        // WARNING: Do not modify the following code unless you know what you are doing. Unhandled push payloads
        // for calls have negative effects for the app execution and installations.
        if TARGET_OS_SIMULATOR != 0 {
           // Do nothing if running simulator, ignore call
        } else if type == .voIP {
            if notificationData == nil { notificationData = MMWebRTCNotificationData() }
            MMLogSecureDebug(String(format: "Received VoIP Push Notification %@", payload.dictionaryPayload))
            saveCallNotificationData(payload)
           if getInfobipRTCInstance().isIncomingApplicationCall(payload) {
               getInfobipRTCInstance().handleIncomingApplicationCall(payload, self)
            } else if getInfobipRTCInstance().isIncomingCall(payload) {
                getInfobipRTCInstance().handleIncomingCall(payload, self)
            } else {
                notificationData = nil
            }
            // Other types of calls are not yet supported
        }
    }
    
    private func saveCallNotificationData(_ payload: PKPushPayload) {
        let dict = payload.dictionaryPayload
         if let customDataJson = dict["customData"] as? String,
             let jsonData = customDataJson.data(using: .utf8) {
             do {
                 notificationData?.customData = (try JSONSerialization.jsonObject(
                     with: jsonData) as? [String: Any]) ?? [:]
             } catch {
                 notificationData?.customData = nil
             }
         }
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        MMWebRTCToken.obtain(queue: q, completion: { result in
            switch result {
            case .Failure(let error):
                MMLogError(error?.localizedDescription ?? "Unknown error in  MMWebRTCToken.obtain")
            case .Success(let response):
                getInfobipRTCInstance().disablePushNotification(response.token)
            case .Cancel:
                MMLogWarn(" MMWebRTCToken.obtain request cancelled.")
            }
        })
    }
    
    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        return true
    }
    
    public var isPhoneOnCall: Bool {
        // Quick way to check if the operating system is handling a call
        return CXCallObserver().calls.contains { $0.hasEnded == false }
    }
    
    private func requestAVPermissions() {
        guard AVAudioSession.sharedInstance().recordPermission == .undetermined else { return }
        AVAudioSession.sharedInstance().requestRecordPermission({ granted in
            if !granted { MMLogDebug("Microphone permission denied.") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                AVCaptureDevice.requestAccess(for: AVMediaType.video) { granted in
                    if !granted { MMLogDebug("Camera permission denied.") }
                }
            }
        })
    }
}

extension MMWebRTCService: ApplicationCallEventListener, WebrtcCallEventListener {
    public func onCallRecordingStarted(_ callRecordingStartedEvent: CallRecordingStartedEvent) {

    }
    
    public func onCallRecordingStopped(_ callRecordingStoppedEvent: CallRecordingStoppedEvent) {

    }
    
    public func onDialogRecordingStarted(_ dialogRecordingStartedEvent: DialogRecordingStartedEvent) {

    }
    
    public func onDialogRecordingStopped(_ dialogRecordingStoppedEvent: DialogRecordingStoppedEvent) {

    }
    
    public func onConferenceRecordingStarted(_ conferenceRecordingStartedEvent: ConferenceRecordingStartedEvent) {

    }
    
    public func onConferenceRecordingStopped(_ conferenceRecordingStoppedEvent: ConferenceRecordingStoppedEvent) {

    }
    
    @objc public func onRemoteCameraVideoAdded(_ cameraVideoAddedEvent: CameraVideoAddedEvent) { }

    @objc public func onRemoteCameraVideoRemoved() { }

    @objc public func onRemoteScreenShareAdded(_ screenShareAddedEvent: ScreenShareAddedEvent) { }

    @objc public func onRemoteScreenShareRemoved() { }

    @objc public func onRemoteMuted() { }

    @objc public func onRemoteUnmuted() { }

    @objc public func onReconnecting(_ callReconnectingEvent: CallReconnectingEvent) { }

    @objc public func onReconnected(_ callReconnectedEvent: CallReconnectedEvent) { }

    @objc public func onEstablished(_ callEstablishedEvent: CallEstablishedEvent) {

        switch notificationData?.activeCall {
        case .applicationCall(let applicationCall):
            if let delegate = delegate {
                delegate.inboundCallEstablished(applicationCall, event: callEstablishedEvent)
            } else if let callController = MobileMessaging.webRTCService?.getInboundCallController(
                incoming: applicationCall, establishedEvent: callEstablishedEvent) {
                PIPKit.show(with: callController)
            }
        case .webRTCCall(let webRTCCall):
            if let delegate = delegate {
                delegate.inboundWebRTCCallEstablished(webRTCCall, event: callEstablishedEvent)
            } else if let callController = MobileMessaging.webRTCService?.getInboundCallController(
                incoming: webRTCCall, establishedEvent: callEstablishedEvent) {
                PIPKit.show(with: callController)
            }
        default: return
        }
        notificationData?.activeCall = nil
    }
    
    @objc public func onHangup(_ : CallHangupEvent) {
        finishCall()
    }
    
    @objc  public func onCallError(_ callErrorEvent: ErrorEvent) {
        // Any error before establishing will end the call. Other non call errors handles by the listener
        // ase handles in onError
        finishCall()
    }
    
    @objc private func finishCall() {
        switch notificationData?.activeCall {
        case .applicationCall(let applicationCall):
            CallKitManager.shared.endApplicationCall(applicationCall)
            applicationCall.applicationCallEventListener = nil
        case .webRTCCall(let webRTCCall):
            CallKitManager.shared.endWebRTCCall(webRTCCall)
            webRTCCall.webrtcCallEventListener = nil
        default: return
        }
        notificationData?.activeCall = nil
    }
    
    // The folling functions are to be handled, after call is established, by the UI component of your choice
    @objc public func onRinging(_ : CallRingingEvent) { }
    @objc public func onEarlyMedia(_ : CallEarlyMediaEvent) { }
    @objc public func onError(_ error: ErrorEvent) { }
    @objc public func onParticipantStartedTalking(_ participantStartedTalkingEvent: ParticipantStartedTalkingEvent) { }
    @objc public func onParticipantStoppedTalking(_ participantStoppedTalkingEvent: ParticipantStoppedTalkingEvent) { }
    @objc public func onCameraVideoAdded(_ cameraVideoAddedEvent: CameraVideoAddedEvent) { }
    @objc public func onCameraVideoUpdated(_ cameraVideoUpdatedEvent: CameraVideoUpdatedEvent) { }
    @objc public func onCameraVideoRemoved() { }
    @objc public func onScreenShareAdded(_ screenShareAddedEvent: ScreenShareAddedEvent) { }
    @objc public func onScreenShareRemoved() {  }
    @objc public func onParticipantCameraVideoAdded(_ participantCameraVideoAddedEvent: ParticipantCameraVideoAddedEvent) { }
    @objc public func onParticipantCameraVideoRemoved(_ participantCameraVideoRemovedEvent: ParticipantCameraVideoRemovedEvent) { }
    @objc public func onParticipantScreenShareAdded(_ participantScreenShareAddedEvent: ParticipantScreenShareAddedEvent) { }
    @objc public func onParticipantScreenShareRemoved(_ participantScreenShareRemovedEvent: ParticipantScreenShareRemovedEvent) { }
    @objc public func onConferenceJoined(_ conferenceJoinedEvent: ConferenceJoinedEvent) { }
    @objc public func onConferenceLeft(_ conferenceLeftEvent: ConferenceLeftEvent) { }
    @objc public func onParticipantJoining(_ participantJoiningEvent: ParticipantJoiningEvent) { }
    @objc public func onParticipantJoined(_ participantJoinedEvent: ParticipantJoinedEvent) { }
    @objc public func onParticipantMuted(_ participantMutedEvent: ParticipantMutedEvent) { }
    @objc public func onParticipantUnmuted(_ participantUnmutedEvent: ParticipantUnmutedEvent) { }
    @objc public func onParticipantDeaf(_ participantDeafEvent: ParticipantDeafEvent) { }
    @objc public func onParticipantUndeaf(_ participantUndeafEvent: ParticipantUndeafEvent) { }
    @objc public func onParticipantLeft(_ participantLeftEvent: ParticipantLeftEvent) { }
    @objc public func onScreenShareRemoved(_ screenShareRemovedEvent: ScreenShareRemovedEvent) { }
    @objc public func onDialogJoined(_ dialogJoinedEvent: DialogJoinedEvent) { }
    @objc public func onDialogLeft(_ dialogLeftEvent: DialogLeftEvent) { }

}


extension MMWebRTCService: IncomingCallEventListener {
    public func onIncomingWebrtcCall(_ incomingWebrtcCallEvent: IncomingWebrtcCallEvent) {
        let incomingWebRTCCall = incomingWebrtcCallEvent.incomingWebrtcCall
        incomingWebRTCCall.webrtcCallEventListener = self
        CallKitManager.shared.startIncomingWebrtcCall(incomingWebRTCCall)
        notificationData?.activeCall = .webRTCCall(incomingWebRTCCall)
    }
}

extension MMWebRTCService: IncomingApplicationCallEventListener {
    public func onIncomingApplicationCall(_ incomingApplicationCallEvent: IncomingApplicationCallEvent) {
        let incomingApplicationCall = incomingApplicationCallEvent.incomingApplicationCall
        incomingApplicationCall.applicationCallEventListener = self
        CallKitManager.shared.startIncomingApplicationCall(incomingApplicationCall)
        notificationData?.activeCall = .applicationCall(incomingApplicationCall)
    }
}
#endif
