//
//  MMCallKitManager.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 19/08/2021.
//  Copyright © 2021 Infobip Ltd. All rights reserved.
//
import Foundation
import CallKit
import AVKit
#if WEBRTCUI_ENABLED
import InfobipRTC

class CallKitManager: NSObject {
    static let shared = CallKitManager()
    private var callKitProvider: CXProvider
    private let callKitCallController = CXCallController()
    private let queue = DispatchQueue(label: "Call-Queue", attributes: .concurrent)
    private var calls: [String: CallRecord] = [:]
    private var applicationCalls: [String: ApplicationCallRecord] = [:]
    private var isVideoInPayload: Bool? {
        return MobileMessaging.webRTCService?.notificationData?.hasVideo
    }
    
    override init() {
        let providerConfiguration = CXProviderConfiguration(localizedName: "InfobipRTC")
        providerConfiguration.ringtoneSound = MobileMessaging.webRTCService?.settings.inboundCallSoundFileName
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.phoneNumber]
        if let appIcon = MobileMessaging.webRTCService?.callAppIcon ??
            UIImage.init(mm_webrtcui_named: "defaultCallAppIcon") {
            providerConfiguration.iconTemplateImageData = appIcon.pngData()
        }
        callKitProvider = CXProvider(configuration: providerConfiguration)
        super.init()
        callKitProvider.setDelegate(self, queue: nil)
    }
    
    // MARK: - WebRTC Call

    func startIncomingWebrtcCall(_ call: IncomingWebrtcCall) {
        guard let uuid = UUID(uuidString: call.id()) else { return }
        addWebRTCCall(uuid, call)
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = CXHandle(type: .phoneNumber, value: call.source().displayIdentifier() ?? call.source().identifier())
        callUpdate.hasVideo = isVideoInPayload ?? call.hasCameraVideo()
        setCallFeatures(callUpdate)
        self.callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { (error) in
            if let err = error {
                MMLogError(String(format: "Failed to report incoming application call: %@", err.localizedDescription))
            } else {
                MMLogDebug("Successfully reported incoming application call.")
            }
        }
        if UserDefaults.standard.bool(forKey: MMWebRTCUIConstants.autoAccept) {
            let callAnswer = CXAnswerCallAction(call: uuid)
            self.provider(callKitProvider, perform: callAnswer)
        }
    }

    func connectWebRTCCall(_ uuidString: String) {
        guard let uuid = calls[uuidString]?.uuid else { return }
        self.callKitProvider.reportOutgoingCall(with: uuid, connectedAt: nil)

        let callUpdate = CXCallUpdate()
        callUpdate.hasVideo = isVideoInPayload ?? false
        setCallFeatures(callUpdate)

        self.callKitProvider.reportCall(with: uuid, updated: callUpdate)
    }
    
    private func addWebRTCCall(_ callUUID: UUID, _ call: WebrtcCall) {
        queue.sync {
            MMLogDebug("Adding call to managed calls.")
            calls[call.id()] = CallRecord(callUUID, call)
        }
    }
    
    func endWebRTCCall(_ call: WebrtcCall) {
        if let uuid = calls[call.id()]?.uuid {
            MMLogDebug("Ending call with new reportCall")
            self.callKitProvider.reportCall(with: uuid, endedAt: nil, reason: .remoteEnded)
            removeApplicationCall(call.id())
        }
    }
    
    // MARK: - Application Call
    func startApplicationCall(_ call: ApplicationCall) {
        guard let callUUID = UUID(uuidString: call.id()) else { return }
        addApplicationCall(callUUID, call)
        let handle = CXHandle(type: .phoneNumber, value: call.applicationId())
        let startCallAction = CXStartCallAction(call: callUUID, handle: handle)
        startCallAction.isVideo = call.hasCameraVideo()
        let transaction = CXTransaction()
        transaction.addAction(startCallAction)
        MMLogDebug("Requesting CallKit call")
        requestTransaction(transaction)
    }
    
    func connectApplicationCall(_ uuidString: String) {
        guard let uuid = applicationCalls[uuidString]?.uuid else { return }
        self.callKitProvider.reportOutgoingCall(with: uuid, connectedAt: nil)
        
        let callUpdate = CXCallUpdate()
        callUpdate.hasVideo = isVideoInPayload ?? false
        setCallFeatures(callUpdate)
        
        self.callKitProvider.reportCall(with: uuid, updated: callUpdate)
    }
    
    func startIncomingApplicationCall(_ call: IncomingApplicationCall) {
        guard let uuid = UUID(uuidString: call.id()) else { return }
        addApplicationCall(uuid, call)
        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = CXHandle(type: .phoneNumber, value: call.from)
        callUpdate.hasVideo = isVideoInPayload ?? call.hasCameraVideo()
        setCallFeatures(callUpdate)
        self.callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { (error) in
            if let err = error {
                MMLogError(String(format: "Failed to report incoming application call: %@", err.localizedDescription))
            } else {
                MMLogDebug("Successfully reported incoming application call.")
            }
        }        
        if UserDefaults.standard.bool(forKey: MMWebRTCUIConstants.autoAccept) {
            let callAnswer = CXAnswerCallAction(call: uuid)
            self.provider(callKitProvider, perform: callAnswer)
        }
    }
    
    func endApplicationCall(_ call: ApplicationCall) {
        if let uuid = applicationCalls[call.id()]?.uuid {
            MMLogDebug("Ending call with new reportCall")
            self.callKitProvider.reportCall(with: uuid, endedAt: nil, reason: .remoteEnded)
            removeApplicationCall(call.id())
        }
    }

    func localHangup(_ callId: String?) {
        guard let uuidString = callId, let uuid = calls[uuidString]?.uuid else { return }
        MMLogDebug("Ending call due to local hangup.")
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction()
        transaction.addAction(endCallAction)
        requestTransaction(transaction)
    }
    
    func localApplicationHangup(_ callId: String?) {
        guard let uuidString = callId, let uuid = applicationCalls[uuidString]?.uuid else { return }
        MMLogDebug("Ending call due to local hangup.")
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction()
        transaction.addAction(endCallAction)
        requestTransaction(transaction)
    }

    func findApplicationCall(_ callId: String?) -> ApplicationCall? {
        guard let uuidString = callId else { return nil }
        return applicationCalls[uuidString]?.call
    }

    private func setCallFeatures(_ callUpdate: CXCallUpdate) {
        callUpdate.supportsDTMF = true
        callUpdate.supportsHolding = false
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
    }
    
    private func removeApplicationCall(_ callId: String?) {
        guard let uuidString = callId else { return }
        if let callIndex = applicationCalls.index(forKey: uuidString) {
            queue.sync {
                MMLogDebug("Removing call from managed calls.")
                applicationCalls.remove(at: callIndex)
            }
        }
    }

    private func addApplicationCall(_ callUUID: UUID, _ call: ApplicationCall) {
        queue.sync {
            MMLogDebug("Adding call to managed calls.")
            applicationCalls[call.id()] = ApplicationCallRecord(callUUID, call)
        }
    }
    
    private func requestTransaction(_ transaction: CXTransaction) {
        self.callKitCallController.request(transaction) { error in
            if let error = error {
                MMLogError("Error requesting transaction: \(error)")
            } else {
                MMLogDebug("Requested transaction successfully")
            }
        }
    }
}

extension CallKitManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        getInfobipRTCInstance().getActiveCall()?.hangup()
        getInfobipRTCInstance().getActiveApplicationCall()?.hangup()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let callId = action.callUUID.uuidString.lowercased()
        if let incoming = calls[callId]?.call as? IncomingCall {
            incoming.accept()
            action.fulfill()
        } else if let incoming = applicationCalls[callId]?.call as? IncomingApplicationCall {
            incoming.accept()
            action.fulfill()
        } else {
            action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        action.fulfill()
        self.callKitProvider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: nil)
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        if getInfobipRTCInstance().getActiveCall() != nil {
            guard let call = calls[action.callUUID.uuidString.lowercased()]?.call else { return }
            guard call.status != .finishing && call.status != .finished else {
                MMLogDebug("Call already ended.")
                return
            }
            if let incoming = call as? IncomingCall, incoming.status != .established {
                incoming.decline()
            } else {
                call.hangup()
            }
        } else if getInfobipRTCInstance().getActiveApplicationCall() != nil {
            guard let call = applicationCalls[action.callUUID.uuidString.lowercased()]?.call else { return }
            guard call.status != .finishing && call.status != .finished else {
                MMLogDebug("Call already ended.")
                return
            }
            if let incoming = call as? IncomingApplicationCall, incoming.status != .established {
                incoming.decline()
            } else {
                call.hangup()
            }
        }
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {}
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        if let activeCall = getInfobipRTCInstance().getActiveCall() {
            do {
                try activeCall.mute(action.isMuted)
                action.fulfill()
            } catch {
                MMLogError("Failed to mute.")
                action.fail()
            }
        } else if let activeApplicationCall = getInfobipRTCInstance().getActiveApplicationCall() {
            do {
                try activeApplicationCall.mute(action.isMuted)
                action.fulfill()
            } catch {
                MMLogError("Failed to mute.")
                action.fail()
            }
        }

    }
    
    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        do {
            try getInfobipRTCInstance().getActiveCall()?.sendDTMF(action.digits)
            action.fulfill()
        } catch {
            MMLogError("Failed to send DTMF.")
            action.fail()
        }
    }
}

class CallRecord {
    let uuid: UUID
    let call: Call
    
    init(_ uuid: UUID, _ call: Call) {
        self.uuid = uuid
        self.call = call
    }
}

class ApplicationCallRecord {
    let uuid: UUID
    let call: ApplicationCall
    
    init(_ uuid: UUID, _ call: ApplicationCall) {
        self.uuid = uuid
        self.call = call
    }
}
#endif
