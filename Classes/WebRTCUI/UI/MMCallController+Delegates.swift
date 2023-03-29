//
//  MMCallController.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 19/08/2021.
//  Copyright © 2021 Infobip Ltd. All rights reserved.
//
import UIKit
#if WEBRTCUI_ENABLED
import InfobipRTC
import AVFoundation
import CallKit

extension MMCallController {
    internal func ringing(callType: MMCallType) {
        self.startRingback()
        self.callStatusLabel.text = MMLoc.notificationRinging
    }

    private func handleBasicsOfEstablishedVideo() {
        self.stopRingback()
        self.showActiveCallViewElements()
        
        let isMuted: Bool = {
            guard let activeCall = activeCall else { return true }
            
            switch activeCall {
            case .applicationCall(let applicationCall):
                return applicationCall.muted()
            case .webRTCCall(let webRTCCall):
                return webRTCCall.muted()
            }
        }()
        
        if UserDefaults.standard.bool(forKey: MMWebRTCUIConstants.autoAccept) ||
            !(isMuted &&
              !MMCallController.isMicAvailable) {
            // we don't have mic permissions - need to disable muted value
            self.isMuted = true
            doApplyMuteValue()
        }
    }
    
    private func updateVideoUI() {
        if hasLocalVideo || hasRemoteVideo {
            self.onVideoCallEstablished()
        } else {
            self.showVideoElements()
            self.showActiveCallViewElements()
        }
    }

    internal func established(call: ActiveCall) {
        switch call {
        case .applicationCall(let applicationCall):
            established(remoteVideoTrack: applicationCall.remoteVideos().values.first?.camera)
            established(localVideoTrack: applicationCall.localCameraTrack())
        case .webRTCCall(let call):
            established(remoteVideoTrack: call.remoteCameraTrack())
            established(localVideoTrack: call.localCameraTrack())
        }
    }

    internal func established(remoteVideoTrack: VideoTrack? = nil) {
        handleBasicsOfEstablishedVideo()
        if remoteVideoTrack != nil {
            self.counterpartImage.isHidden = true
            self.initRemoteVideoView()
            if let remoteView = self.remoteView {
                remoteVideoTrack!.addRenderer(remoteView)
            }
        } else {
            self.counterpartImage.isHidden = false
        }
        updateVideoUI()
    }

    internal func established(localVideoTrack: VideoTrack? = nil) {
        handleBasicsOfEstablishedVideo()
        if localVideoTrack != nil {
            if MMCallController.isCamAvailable {
                self.localVideoView.isHidden = false
                self.initLocalVideoView()
                if let localView = self.localView {
                    localVideoTrack!.addRenderer(localView)
                }
            } else {
                self.localVideoView.isHidden = true
            }
        } else {
            self.localVideoView.isHidden = true
        }
        updateVideoUI()
    }
    
    internal func updated(remoteVideoTrack: VideoTrack? = nil) {
        if remoteVideoTrack != nil && counterpartImage.isHidden == false {
            counterpartImage.isHidden = true
            initRemoteVideoView()
            if let remoteVideoTrack = remoteVideoTrack,
               let remoteView = remoteView {
                remoteVideoTrack.addRenderer(remoteView)
            }
        } else if remoteVideoTrack == nil && counterpartImage.isHidden == true {
            remoteView?.removeFromSuperview()
            counterpartImage.isHidden = false
            remoteView?.isHidden = true
        }
        updateVideoUI()
    }
    
    internal func updated(localVideoTrack: VideoTrack? = nil) {
        if localVideoTrack != nil {
            localVideoView.isHidden = false
            initLocalVideoView()
            if let localVideoTrack = localVideoTrack,
               let localView = localView {
                localVideoTrack.addRenderer(localView)
            }
        } else if localVideoTrack == nil && self.localVideoView.isHidden == false {
            localVideoView.isHidden = true
        }
        videoStatusBottomView.localVideo.isSelected = localVideoTrack != nil
        updateVideoUI()
    }

    internal func hangup(errorCodeName: String) {
        self.finalizeCallPreview("Status: \(errorCodeName)")
        self.stopRingback()
    }
}

extension MMCallController: NetworkQualityEventListener {
    private func setNetworkStatusLabel() {
        if self.localNetworkQuality.getScore() <= NetworkQuality.poor.getScore() {
            self.networkStatusLabel.textColor = .red
        } else if self.localNetworkQuality == NetworkQuality.fair {
            self.networkStatusLabel.textColor = .yellow
        }

        if self.localNetworkQuality.getScore() <= NetworkQuality.fair.getScore() {
            self.networkStatusLabel.isHidden = false
            self.networkStatusLabel.text = "Your network is causing poor call quality"
        } else if self.remoteNetworkQuality.getScore() <= NetworkQuality.poor.getScore() {
            self.networkStatusLabel.isHidden = false
            self.networkStatusLabel.textColor = .cyan
            self.networkStatusLabel.text = "Remote user\'s network is causing poor call quality"
        } else {
            self.networkStatusLabel.isHidden = true
        }
    }
    
    public func onRemoteNetworkQualityChanged(_ networkQualityChangedEvent: NetworkQualityChangedEvent) {
        self.remoteNetworkQuality = networkQualityChangedEvent.networkQuality
        MMLogDebug(String(format: "Remote network quality changed: %s (%d)",
                          self.remoteNetworkQuality.getName(),
                          self.remoteNetworkQuality.getScore()))
        setNetworkStatusLabel()
    }

    public func onNetworkQualityChanged(_ networkQualityChangedEvent: NetworkQualityChangedEvent) {
        self.localNetworkQuality = networkQualityChangedEvent.networkQuality
        MMLogDebug(String(format: "Local network quality changed: %s (%d)",
                          self.localNetworkQuality.getName(),
                          self.localNetworkQuality.getScore()))
        setNetworkStatusLabel()
    }
}

// MARK: Permission extension
extension MMCallController {
    class func checkMicPermission(completion: @escaping (Bool) -> Void) {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission({ granted in
                completion(granted)
            })
        @unknown default:
            completion(false)
        }
    }

    class func checkCamPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        default:
            AVCaptureDevice.requestAccess(for: AVMediaType.video) { granted in
                completion(granted)
            }
        }
    }

    class internal var isMicAvailable: Bool {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }

    class internal var isCamAvailable: Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
}
#endif
