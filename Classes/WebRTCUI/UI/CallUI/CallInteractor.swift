//
//  CallInteractor.swift
//  MobileMessaging
//
//  Created by Maksym Svitlovskyi on 03/10/2023.
//

import Foundation
#if WEBRTCUI_ENABLED
import InfobipRTC
import AVFoundation

class ReconnectingPlayer: NSObject, AVAudioPlayerDelegate {
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    private var isLoopingWithDelay: Bool = false
    
    func startReconnecting() {
        self.cleanPlayer()

        guard let url = getData(false) else { return }
        
        guard let player = try? AVAudioPlayer(data: url) else { return }
        
        self.player = player
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.player?.play()
        }
    }
    
    func reconnected() {
        self.cleanPlayer()
        
        guard let data = getData(true) else { return }
        
        guard let player = try? AVAudioPlayer(data: data) else { return }
        self.player = player
        self.player?.play()
    }
    
    func cleanPlayer() {
        self.timer?.invalidate()
        self.player?.stop()
        self.player = nil
    }
    
    private func getData(_ forReconnectedAudio: Bool) -> Data? {
        let name = forReconnectedAudio ? "reconnected" : "reconnecting"
        let media = NSDataAsset(mm_webrtcui_named: name)
        return media?.data
    }
}

class CallInteractor {
    
    var currentCall: ActiveCall?
    var showErrorAlert: ((String) -> Void)?
    // MARK: - Audio Player
    var player: AVAudioPlayer?
    lazy var reconnectingPlayer: ReconnectingPlayer = ReconnectingPlayer()

    func playDisconnectCall() {
        if player != nil {
            player?.stop()
            player = nil
        }
        if let assetdata = MobileMessaging.webRTCService?.settings.soundEndCall.data {
            do {
                player = try AVAudioPlayer(data: assetdata)
                player?.currentTime = 0
                player?.numberOfLoops = 1
                player?.prepareToPlay()
                player?.play()
            } catch {
                MMLogDebug("Error starting ringback tone")
            }
        } else {
            fatalError("Unable to find asset soundEndCall")
        }
    }
    // MARK: - Call Actions
    func hangup() {
        guard let currentCall = currentCall else { return }

        switch currentCall {
        case .applicationCall(let applicationCall):
            applicationCall.applicationCallEventListener = nil
            applicationCall.hangup()
            CallKitManager.shared.localApplicationHangup(applicationCall.id())
            CallKitManager.shared.endApplicationCall(applicationCall)
        case .webRTCCall(let webrtcCall):
            webrtcCall.webrtcCallEventListener = nil
            webrtcCall.hangup()
            CallKitManager.shared.localApplicationHangup(webrtcCall.id())
            CallKitManager.shared.endWebRTCCall(webrtcCall)
        }
    }
    
    func screenShareToggle() -> Bool? {
        guard let activeCall = currentCall else { return nil  }

        do {
            let isSharing: Bool
            switch activeCall {
            case .applicationCall(let applicationCall):
                isSharing = applicationCall.hasScreenShare()
                try applicationCall.screenShare(screenShare: !isSharing)
                return isSharing
            case .webRTCCall(let webRTCCall):
                isSharing = webRTCCall.hasScreenShare()
                try webRTCCall.screenShare(screenShare: !isSharing)
                return isSharing
            }
            
        } catch let error as CallError {
            showErrorAlert?(error.localizedDescription)
        } catch {
            showErrorAlert?(MMLoc.somethingWentWrong)
        }
        return nil
    }
    
    func micToggle() -> Bool? {
        guard let currentCall = currentCall else { return nil }
        do {
            let shouldMute: Bool
            switch currentCall {
            case .applicationCall(let applicationCall):
                shouldMute = !applicationCall.muted()
                try applicationCall.mute(shouldMute)
            case .webRTCCall(let webrtcCall):
                shouldMute = !webrtcCall.muted()
                try webrtcCall.mute(shouldMute)
            }
            return shouldMute
        } catch let error as ApplicationCallError {
            showErrorAlert?(error.description)
        } catch {
            showErrorAlert?(error.localizedDescription)
        }
        return nil
    }
    
    func videoToggle(completion: ((Bool) -> Void)?) {
        CallInteractor.checkCamPermission(completion: { [weak self] granted in
            if granted {
                do {
                    if let activeCall = self?.currentCall {
                        switch activeCall {
                        case .applicationCall(let applicationCall):
                            try applicationCall.cameraVideo(cameraVideo: !applicationCall.hasCameraVideo())
                            completion?(applicationCall.hasCameraVideo())
                        case .webRTCCall(let webRTCCall):
                            try webRTCCall.cameraVideo(cameraVideo: !webRTCCall.hasCameraVideo())
                            completion?(webRTCCall.hasCameraVideo())
                        }
                    }
                } catch let error as CallError {
                    self?.showErrorAlert?(error.localizedDescription)
                } catch {
                    self?.showErrorAlert?(MMLoc.somethingWentWrong)
                }
            } else {
                completion?(false)
            }
        })
    }
    
    func flipCamera() {
        if let activeCall = currentCall {
            switch activeCall {
            case .applicationCall(let applicationCall):
                applicationCall.cameraOrientation(
                    applicationCall.cameraOrientation() == .front ? .back : .front)
            case .webRTCCall(let webRTCCall):
                webRTCCall.cameraOrientation(
                    webRTCCall.cameraOrientation() == .front ? .back : .front)
            }
        }
    }
    
    func toggleSpeakerphone(completion: @escaping (Bool?) -> Void) {
        if let activeCall = currentCall {
            
            let onErrorCompletion: (Error?) -> Void = { error in
                DispatchQueue.mmEnsureMain {
                    guard let error = error else { return }
                    self.showErrorAlert?(error.localizedDescription)
                }
                completion(nil)
            }
            
            switch activeCall {
            case .applicationCall(let applicationCall):
                let isSpeakerphone = applicationCall.speakerphone()
                applicationCall.speakerphone(!isSpeakerphone, onErrorCompletion)
                completion(!isSpeakerphone)
            case .webRTCCall(let webRTCCall):
                let isSpeakerphone = webRTCCall.speakerphone()
                webRTCCall.speakerphone(!isSpeakerphone, onErrorCompletion)
                completion(!isSpeakerphone)
            }
        }
    }
    // MARK: Utilities
    func getFormattedCallDuration() -> String {
        if let currentCall = currentCall {
            return formatTimeString(from: currentCall.duration)
        }
        return "00:00"
    }
    
    private func formatTimeString(from interval: Int) -> String {
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / (60*60)) % 60
        return hours > 0 ? String(format: "%02i:%02i:%02i", hours, minutes, seconds) : String(format: "%02i:%02i", minutes, seconds)
    }
}

// MARK: Permission extension
extension CallInteractor {
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
