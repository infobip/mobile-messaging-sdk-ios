// 
//  MMWebRTCService+Push.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import WebKit
import CallKit
import PushKit
import AVFoundation

#if WEBRTCUI_ENABLED
import InfobipRTC
import InfobipMobileUI

extension MMWebRTCService: PKPushRegistryDelegate {
    func createCallsPushRegistry() {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self else { return }
            guard self.isCallKitSupported() else {
                self.delegate?.callRegistrationEnded(with: .callsNotSupportedError, and: nil)
                return
            }
            guard self.callsPushRegistry == nil else { return }
            let registry = PKPushRegistry(queue: self.callsPushDelegateQueue)
            self.callsPushRegistry = registry
            registry.delegate = self
            registry.desiredPushTypes = [.voIP]
        }
    }
    
    public func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate pushCredentials: PKPushCredentials,
        for type: PKPushType)
    {
        guard type == .voIP else { return }
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self,
                  !self.retiredCallPushRegistries.contains(registry),
                  self.isCallKitSupported() else { return }
            self.useCallPushCredentials(pushCredentials)
        }
    }
    
    func invalidatePendingCallRegistration() {
        cancelCallRegistrationTimeout()
        registrationGeneration &+= 1 // '&' wraps around in case of overflow in the data type
        registrationPhase = .idle
        enablingCallPushToken = nil
    }

    private func cancelCallRegistrationTimeout() {
        registrationTimeoutWorkItem?.cancel()
        registrationTimeoutWorkItem = nil
    }

    private func scheduleCallRegistrationTimeout(
        for generation: UInt64,
        expectedPhase: MMCallRegistrationPhase,
        credentials: PKPushCredentials)
    {
        cancelCallRegistrationTimeout()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self,
                  self.registrationGeneration == generation,
                  self.pendingDisableCallPush == nil else { return }

            switch (expectedPhase, self.registrationPhase) {
            case (.obtainingToken, .obtainingToken):
                MMLogWarn("[WebRTCUI] timed out obtaining a token to enable call push")
                self.invalidatePendingCallRegistration()
                if let latestCredentials = self.currentPushCredentials,
                   latestCredentials.token != credentials.token {
                    self.retryCallRegistrationIfNeeded()
                } else {
                    self.delegate?.callRegistrationEnded(with: .gettingTokenError, and: nil)
                }
            case (.enabling(let expectedRetry), .enabling(let currentRetry)) where expectedRetry == currentRetry:
                MMLogWarn("[WebRTCUI] timed out enabling call push")
                let token = self.enablingCallPushToken
                let credentialsChanged = self.currentPushCredentials.map { $0.token != credentials.token } ?? false
                self.invalidatePendingCallRegistration()
                self.isRegistered = false
                self.registeredPushToken = nil
                // The RTC operation may have succeeded without delivering its callback.
                self.requestCallPushDisabling(nil, notifyDelegate: false)
                self.pendingDisableCallPush?.timedOutEnableToken = token
                if credentialsChanged && self.isRunning {
                    self.pendingDisableCallPush?.retryAfterCompletion = true
                }
                self.delegate?.callRegistrationEnded(with: .registeringForCallsError, and: nil)
            default:
                break
            }
        }
        registrationTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.callPushOperationTimeout, execute: timeout)
    }

    func retryCallRegistrationIfNeeded() {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self, let credentials = self.currentPushCredentials else { return }
            self.useCallPushCredentials(credentials)
        }
    }

    private func requestCallPushEnabling(
        with token: String,
        credentials: PKPushCredentials,
        configurationId: String,
        generation: UInt64,
        isRetrying: Bool = false)
    {
        guard registrationGeneration == generation else { return }
        switch (isRetrying, registrationPhase) {
        // Note: obtainingToken here doesn't mean a token is yet to be received, it means token was requested, and is received, but the registrationPhase has not advanced yet. The token is valid - the only risk (low) of it being invalid would be case (true, .obtainingToken), while retrying
        case (false, .obtainingToken), (true, .waitingToRetry): break
        default: return
        }
        if pendingDisableCallPush == nil && currentPushCredentials?.token != credentials.token {
            // PushKit replaced the token before this enable reached RTC.
            registrationPhase = .idle
            retryCallRegistrationIfNeeded()
            return
        }
        registrationPhase = .enabling(isRetrying: isRetrying)
        enablingCallPushToken = token
        scheduleCallRegistrationTimeout(for: generation,
                                        expectedPhase: .enabling(isRetrying: isRetrying),
                                        credentials: credentials)
        var isDebugging = false
        // isDebugging flag will determine if the WebRTC calls use Production of Sandboxing modes/certificates
        #if DEBUG
            isDebugging = true
        #endif

        getInfobipRTCInstance().enablePushNotification(
            token,
            pushCredentials: credentials,
            debug: isDebugging,
            pushConfigId: configurationId) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let succeeded: Bool
                switch result.status {
                case .failure: succeeded = false
                default: succeeded = true
                }
                self.handleCallPushEnablingCompletion(
                    succeeded: succeeded,
                    token: token,
                    credentials: credentials,
                    configurationId: configurationId,
                    generation: generation,
                    isRetrying: isRetrying)
            }
        }
    }

    private func handleCallPushEnablingCompletion(
        succeeded: Bool,
        token: String,
        credentials: PKPushCredentials,
        configurationId: String,
        generation: UInt64,
        isRetrying: Bool)
    {
        guard registrationGeneration == generation,
              case .enabling(let currentIsRetrying) = registrationPhase,
              currentIsRetrying == isRetrying else {
            if succeeded {
                reconcileLateCallPushOperation(token: token)
            }
            return
        }
        cancelCallRegistrationTimeout()

        let isCurrentPushToken = currentPushCredentials?.token == credentials.token
        if !succeeded, !isRetrying,
           pendingDisableCallPush == nil, isCurrentPushToken {
            enablingCallPushToken = nil
            registrationPhase = .waitingToRetry
            scheduleCallPushEnableRetry(with: token,
                                        credentials: credentials,
                                        configurationId: configurationId,
                                        generation: generation)
            return
        }

        registrationPhase = .idle
        enablingCallPushToken = nil
        if succeeded {
            // RTC may have enabled even when a pending disable suppresses the delegate callback.
            isRegistered = true
            registeredPushToken = credentials.token
            if pendingDisableCallPush == nil && isCurrentPushToken {
                delegate?.callRegistrationEnded(with: .success, and: nil)
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil)
            }
        } else {
            MMLogDebug("Failure: can't enable WebRTC call push notifications")
            if pendingDisableCallPush == nil && isCurrentPushToken {
                isRegistered = false
                delegate?.callRegistrationEnded(with: .registeringForCallsError, and: nil)
            }
        }

        if pendingDisableCallPush != nil {
            // RTC enable has settled, so a fresh token can now be used to disable it in order.
            continuePendingCallPushDisabling()
        } else if !isCurrentPushToken {
            retryCallRegistrationIfNeeded()
        }
    }

    private func reconcileLateCallPushOperation(token: String) {
        // A timed-out enable or token request may complete after the disable request has ended.
        // Use its original token, since the chat identity may have changed since then.
        let hasNewRegistration = pendingDisableCallPush == nil && (registrationPhase.isRegistering || isRegistered)
        getInfobipRTCInstance().disablePushNotification(token)
        guard hasNewRegistration else { return }

        // The late disable may also affect a newer registration on the RTC instance.
        // Finish that registration, disable it, then retry the current credentials.
        isRegistered = false
        registeredPushToken = nil
        requestCallPushDisabling(nil, notifyDelegate: false)
        pendingDisableCallPush?.retryAfterCompletion = true
    }

    private func scheduleCallPushEnableRetry(
        with token: String,
        credentials: PKPushCredentials,
        configurationId: String,
        generation: UInt64)
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.requestCallPushEnabling(with: token,
                                          credentials: credentials,
                                          configurationId: configurationId,
                                          generation: generation,
                                          isRetrying: true)
        }
    }

    /// Call this to forward credentials from an app-owned PushKit registry.
    public func useCallPushCredentials(_ pushCredentials: PKPushCredentials) {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self else { return }
            self.currentPushCredentials = pushCredentials
            if let pendingDisableCallPush = self.pendingDisableCallPush {
                pendingDisableCallPush.retryAfterCompletion = pendingDisableCallPush.retryAfterCompletion || self.isRunning
                return
            }
            // A changed PushKit token waits for the current RTC enable to finish.
            guard case .idle = self.registrationPhase else { return }
            if self.registeredPushToken != nil && self.registeredPushToken != pushCredentials.token {
                self.isRegistered = false
                self.registeredPushToken = nil
            }
            guard
                  self.isRunning,
                  !self.isShuttingDown,
                  self.mmContext.currentInstallation().pushRegistrationId != nil,
                  self.identity != nil,
                  let configurationId = self.configurationId,
                  !self.isRegistered else { return }

            self.registrationGeneration &+= 1
            let generation = self.registrationGeneration
            self.registrationPhase = .obtainingToken
            self.scheduleCallRegistrationTimeout(for: generation,
                                                 expectedPhase: .obtainingToken,
                                                 credentials: pushCredentials)
            let tokenContext = MMWebRTCTokenRequestContext(mmContext: self.mmContext, identity: self.identity)
            if let tokenContext { self.lastCallPushTokenContext = tokenContext }
            MMWebRTCToken.obtain(queue: self.q, context: tokenContext) { [weak self] result in
                DispatchQueue.main.async { [weak self] in
                    guard let self,
                          self.registrationGeneration == generation,
                          case .obtainingToken = self.registrationPhase else { return }
                    self.cancelCallRegistrationTimeout()
                    switch result {
                    case .Success(let response):
                        self.requestCallPushEnabling(with: response.token,
                                                     credentials: pushCredentials,
                                                     configurationId: configurationId,
                                                     generation: generation)
                    case .Failure(let error):
                        self.registrationPhase = .idle
                        if self.currentPushCredentials?.token == pushCredentials.token {
                            self.delegate?.callRegistrationEnded(with: .gettingTokenError, and: error)
                        } else {
                            self.retryCallRegistrationIfNeeded()
                        }
                    case .Cancel:
                        self.registrationPhase = .idle
                        if self.currentPushCredentials?.token == pushCredentials.token {
                            self.delegate?.callRegistrationEnded(with: .gettingTokenError, and: nil)
                        } else {
                            self.retryCallRegistrationIfNeeded()
                        }
                    }
                }
            }
        }
    }

    /// Requests disabling the current RTC registration. A running service may register again on a later PushKit update or automatic retry
    public func disableCallPushCredentials(_ completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self else { completion?(false); return }
            self.requestCallPushDisabling(completion, notifyDelegate: true)
        }
    }

    func requestCallPushDisabling(_ completion: ((Bool) -> Void)?, notifyDelegate: Bool) {
        cancelCallRegistrationTimeout()
        if let pendingDisableCallPush {
            pendingDisableCallPush.notifyDelegate = pendingDisableCallPush.notifyDelegate || notifyDelegate
            if let completion { pendingDisableCallPush.completions.append(completion) }
            return
        }
        let request = MMCallPushDisablingRequest()
        request.notifyDelegate = notifyDelegate
        // Keep the old identity and HTTP provider available if RTC enabling outlives SDK shutdown.
        request.tokenContext = shutdownTokenContext ?? MMWebRTCTokenRequestContext(mmContext: mmContext, identity: identity)
        if let completion { request.completions.append(completion) }
        pendingDisableCallPush = request
        // Token retrieval does not change RTC state, so overlap it with any in-flight enable to avoid timeouts accumulation.
        // The RTC disable itself still waits for the enable to settle.
        scheduleCallPushTokenTimeout(for: request)
        obtainFreshTokenAndDisableCallPush(for: request)
        // Token acquisition and scheduled retries have not reached RTC and can be cancelled locally.
        // An enable already in flight must settle before disable is sent.
        switch registrationPhase {
        case .obtainingToken, .waitingToRetry:
            invalidatePendingCallRegistration()
        default:
            break
        }
        continuePendingCallPushDisabling()
    }

    func continuePendingCallPushDisabling() {
        guard let request = pendingDisableCallPush, !request.isDisabling else { return }
        guard case .idle = registrationPhase else {
            scheduleCallPushDisablingTimeout(for: request)
            return
        }
        request.enableWaitTimeoutWorkItem?.cancel()
        request.enableWaitTimeoutWorkItem = nil
        request.isDisabling = true
        if let result = request.tokenResult {
            finishCallPushDisabling(result, request: request)
        }
    }

    private func scheduleCallPushDisablingTimeout(for request: MMCallPushDisablingRequest) {
        guard request.enableWaitTimeoutWorkItem == nil else { return }
        let timeout = DispatchWorkItem { [weak self, weak request] in
            guard let self, let request,
                  self.pendingDisableCallPush === request,
                  !request.isDisabling else { return }
            MMLogWarn("[WebRTCUI] timed out waiting for call push enabling before disabling request")
            // Do not let a missing RTC callback block every future registration.
            // A late success is compensated by handleCallPushEnablingCompletion.
            request.timedOutEnableToken = self.enablingCallPushToken
            self.invalidatePendingCallRegistration()
            self.continuePendingCallPushDisabling()
        }
        request.enableWaitTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.callPushOperationTimeout, execute: timeout)
    }

    private func scheduleCallPushTokenTimeout(for request: MMCallPushDisablingRequest) {
        let timeout = DispatchWorkItem { [weak self, weak request] in
            guard let self, let request,
                  self.pendingDisableCallPush === request,
                  request.tokenResult == nil else { return }
            MMLogWarn("[WebRTCUI] timed out obtaining a token to disable call push")
            request.tokenResult = .Failure(nil)
            if request.isDisabling {
                self.finishCallPushDisabling(.Failure(nil), request: request)
            }
        }
        request.tokenTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.callPushOperationTimeout, execute: timeout)
    }

    private func obtainFreshTokenAndDisableCallPush(for request: MMCallPushDisablingRequest) {
        let requestID = request.id
        MMWebRTCToken.obtain(queue: q, context: request.tokenContext) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let request = self.pendingDisableCallPush, request.id == requestID {
                    request.tokenTimeoutWorkItem?.cancel()
                    request.tokenTimeoutWorkItem = nil
                    request.tokenResult = result
                    if request.isDisabling {
                        self.finishCallPushDisabling(result, request: request)
                    }
                } else if case .Success(let response) = result {
                    self.reconcileLateCallPushOperation(token: response.token)
                }
            }
        }
    }

    private func finishCallPushDisabling(_ result: MMResult<MMWebRTCToken>, request: MMCallPushDisablingRequest) {
        request.enableWaitTimeoutWorkItem?.cancel()
        request.enableWaitTimeoutWorkItem = nil
        request.tokenTimeoutWorkItem?.cancel()
        request.tokenTimeoutWorkItem = nil
        let statusCode: MMWebRTCRegistrationCode
        let statusError: Error?
        switch result {
        case .Success(let response):
            getInfobipRTCInstance().disablePushNotification(response.token)
            if let timedOutEnableToken = request.timedOutEnableToken,
               timedOutEnableToken != response.token {
                getInfobipRTCInstance().disablePushNotification(timedOutEnableToken)
            }
            isRegistered = false
            registeredPushToken = nil
            callPushRegistrationMayStillBeActive = false
            statusCode = .success
            statusError = nil
        case .Failure(let error):
            MMLogError("[WebRTCUI] \(error?.localizedDescription ?? "Unable to obtain WebRTC token for call push disable")")
            if let token = request.timedOutEnableToken {
                getInfobipRTCInstance().disablePushNotification(token)
            }
            callPushRegistrationMayStillBeActive = true
            isRegistered = false
            registeredPushToken = nil
            statusCode = .gettingTokenError
            statusError = error
        case .Cancel:
            MMLogWarn("[WebRTCUI] token request for call push disable was cancelled")
            if let token = request.timedOutEnableToken {
                getInfobipRTCInstance().disablePushNotification(token)
            }
            callPushRegistrationMayStillBeActive = true
            isRegistered = false
            registeredPushToken = nil
            statusCode = .gettingTokenError
            statusError = nil
        }

        pendingDisableCallPush = nil
        let completions = request.completions
        request.completions.removeAll()
        completions.forEach { $0(statusCode == .success) }
        if request.notifyDelegate {
            delegate?.callUnregistrationEnded(with: statusCode, and: statusError)
        }
        if statusCode == .success {
            processPendingChatRegistration()
        }
        // A replacement PushKit token still needs registration if disabling failed;
        // local registration state was cleared above, and no chat identity switch is pending.
        if request.retryAfterCompletion && isRunning && pendingInAppChatRegistrationId == nil {
            retryCallRegistrationIfNeeded()
        }
    }
        
    public func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        // WARNING: Do not modify the following code unless you know what you are doing. Unhandled push payloads
        // for calls have negative effects for the app execution and installations.
#if targetEnvironment(simulator)
           // Do nothing if running simulator, ignore call
#else
        if type == .voIP {
            updateNotificationData { data in
                if data == nil { data = MMWebRTCNotificationData() }
            }
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
#endif
    }
    
    private func saveCallNotificationData(_ payload: PKPushPayload) {
        let dict = payload.dictionaryPayload
         if let customDataJson = dict["customData"] as? String,
             let jsonData = customDataJson.data(using: .utf8) {
             do {
                 let customData = (try JSONSerialization.jsonObject(
                     with: jsonData) as? [String: Any]) ?? [:]
                 updateNotificationData { $0?.customData = customData }
             } catch {
                 updateNotificationData { $0?.customData = nil }
             }
         }
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self,
                  !self.retiredCallPushRegistries.contains(registry) else { return }
            self.currentPushCredentials = nil
            // A replacement token may arrive while disable waits for the old RTC enable.
            self.requestCallPushDisabling(nil, notifyDelegate: false)
        }
    }
    
    func application(_ application: UIApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        return true
    }
    
    public var isPhoneOnCall: Bool {
        // Quick way to check if the operating system is handling a call
        return callObserver.calls.contains { $0.hasEnded == false }
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
    public func onTalkingWhileMuted(_ talkingWhileMuted: TalkingWhileMutedEvent) { }
    
    public func onStartedTalking(_ startedTalkingEvent: StartedTalkingEvent) { }
    
    public func onStoppedTalking(_ stoppedTalkingEvent: StoppedTalkingEvent) { }
    
    public func onMessageReceived(_ messageReceivedEvent: MessageReceivedEvent) { }
    
    public func onCameraVideoRemoved(_ cameraVideoRemovedEvent: CameraVideoRemovedEvent) { }

    public func onParticipantBlinded(_ participantBlindedEvent: ParticipantBlindedEvent) { }

    public func onParticipantUnblinded(_ participantUnblindedEvent: ParticipantUnblindedEvent) { }

    public func onRoleChanged(_ roleChangedEvent: RoleChangedEvent)  { }

    public func onParticipantRoleChanged(_ participantRoleChangedEvent: ParticipantRoleChangedEvent) { }

    public func onParticipantDisconnected(_ participantDisconnectedEvent: ParticipantDisconnectedEvent) { }
    
    public func onParticipantReconnected(_ participantReconnectedEvent: ParticipantReconnectedEvent) { }
    
    public func onRemoteDisconnected(_ remoteDisconnectedEvent: RemoteDisconnectedEvent) { }
    
    public func onRemoteReconnected(_ remoteReconnectedEvent: RemoteReconnectedEvent) { }
    
    public func onCallRecordingStarted(_ callRecordingStartedEvent: CallRecordingStartedEvent) { }
    
    public func onCallRecordingStopped(_ callRecordingStoppedEvent: CallRecordingStoppedEvent) { }
    
    public func onDialogRecordingStarted(_ dialogRecordingStartedEvent: DialogRecordingStartedEvent) { }
    
    public func onDialogRecordingStopped(_ dialogRecordingStoppedEvent: DialogRecordingStoppedEvent) { }
    
    public func onConferenceRecordingStarted(_ conferenceRecordingStartedEvent: ConferenceRecordingStartedEvent) { }
    
    public func onConferenceRecordingStopped(_ conferenceRecordingStoppedEvent: ConferenceRecordingStoppedEvent) { }
    
    @objc public func onRemoteCameraVideoAdded(_ cameraVideoAddedEvent: CameraVideoAddedEvent) { }

    @objc public func onRemoteCameraVideoRemoved() { }

    @objc public func onRemoteScreenShareAdded(_ screenShareAddedEvent: ScreenShareAddedEvent) { }

    @objc public func onRemoteScreenShareRemoved() { }

    @objc public func onRemoteMuted() { }

    @objc public func onRemoteUnmuted() { }

    @objc public func onReconnecting(_ callReconnectingEvent: CallReconnectingEvent) { }

    @objc public func onReconnected(_ callReconnectedEvent: CallReconnectedEvent) { }

    @objc public func onEstablished(_ callEstablishedEvent: CallEstablishedEvent) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            switch self.notificationData?.activeCall {
            case .applicationCall(let applicationCall):
                if let delegate = self.delegate {
                    delegate.inboundCallEstablished(applicationCall, event: callEstablishedEvent)
                } else if let callController = MobileMessaging.webRTCService?.getInboundCallController(
                    incoming: applicationCall, establishedEvent: callEstablishedEvent) {
                    IBPIPKit.show(with: callController)
                }
            case .webRTCCall(let webRTCCall):
                if let delegate = self.delegate {
                    delegate.inboundWebRTCCallEstablished(webRTCCall, event: callEstablishedEvent)
                } else if let callController = MobileMessaging.webRTCService?.getInboundCallController(
                    incoming: webRTCCall, establishedEvent: callEstablishedEvent) {
                    IBPIPKit.show(with: callController)
                }
            default: return
            }
            self.updateNotificationData { $0?.activeCall = nil }
        }
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
        switch takeActiveNotificationCall() {
        case .applicationCall(let applicationCall):
            CallKitManager.shared.endApplicationCall(applicationCall)
            applicationCall.applicationCallEventListener = nil
        case .webRTCCall(let webRTCCall):
            CallKitManager.shared.endWebRTCCall(webRTCCall)
            webRTCCall.webrtcCallEventListener = nil
        default: return
        }
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
    @objc public func onMachineDetectionFinished(_ machineDetectionFinishedEvent: MachineDetectionFinishedEvent) { }
    @objc public func onMachineDetectionFailed(_ machineDetectionFailedEvent: MachineDetectionFailedEvent) { }
}


extension MMWebRTCService: IncomingCallEventListener {
    public func onIncomingWebrtcCall(_ incomingWebrtcCallEvent: IncomingWebrtcCallEvent) {
        let incomingWebRTCCall = incomingWebrtcCallEvent.incomingWebrtcCall
        incomingWebRTCCall.webrtcCallEventListener = self
        CallKitManager.shared.startIncomingWebrtcCall(incomingWebRTCCall)
        updateNotificationData { $0?.activeCall = .webRTCCall(incomingWebRTCCall) }
    }
}

extension MMWebRTCService: IncomingApplicationCallEventListener {
    public func onIncomingApplicationCall(_ incomingApplicationCallEvent: IncomingApplicationCallEvent) {
        let incomingApplicationCall = incomingApplicationCallEvent.incomingApplicationCall
        incomingApplicationCall.applicationCallEventListener = self
        CallKitManager.shared.startIncomingApplicationCall(incomingApplicationCall)
        updateNotificationData { $0?.activeCall = .applicationCall(incomingApplicationCall) }
    }
}

// MARK: - Async/Await Alternatives
extension MMWebRTCService {
    /**
     Disables call push credentials using async/await.
     - returns: Boolean indicating success or failure.
     */
    public func disableCallPushCredentials() async -> Bool {
        await withCheckedContinuation { continuation in
            self.disableCallPushCredentials { success in
                continuation.resume(returning: success)
            }
        }
    }
}
#endif
