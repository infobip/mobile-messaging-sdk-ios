//
//  MMCallController.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 19/08/2021.
//  Copyright © 2021 Infobip Ltd. All rights reserved.
//
import UIKit
import AVFoundation
import CallKit
#if WEBRTCUI_ENABLED
import InfobipRTC


enum ActiveCall {
    case applicationCall(ApplicationCall)
    case webRTCCall(WebrtcCall)
}

extension ActiveCall {
    var duration: Int {
        switch self {
        case .applicationCall(let applicationCall):
            return applicationCall.duration()
        case .webRTCCall(let webRTCCall):
            return webRTCCall.duration()
        }
    }
}

class ActiveCallTracks {
    private var remoteCameraVideoTrack: VideoTrack?
    private var remoteSharingVideoTrack: VideoTrack?
    var activeVideoTrack: VideoTrack?

    var isAnyVideoTrack: Bool {
        return remoteCameraVideoTrack != nil || remoteSharingVideoTrack != nil
    }

    func add(track: VideoTrack, isScreensharing: Bool) {
        if isScreensharing {
            self.remoteSharingVideoTrack = track
        } else {
            self.remoteCameraVideoTrack = track
        }
        self.activeVideoTrack = track
    }
    /// Return new active video track, If it exist
    func remove(isScreensharing: Bool) -> VideoTrack? {
        if isScreensharing {
            self.remoteSharingVideoTrack = nil
        } else {
            self.remoteCameraVideoTrack = nil
        }

        let notNilVideoTrack = remoteCameraVideoTrack ?? remoteSharingVideoTrack

        if let notNilVideoTrack = notNilVideoTrack, activeVideoTrack != notNilVideoTrack {
            activeVideoTrack = notNilVideoTrack
            return activeVideoTrack
        }

        return nil
    }
}

public class MMCallController: UIViewController, MMOpenSettings, MMPIPUsable {
    func applySettings() {
        let settings = MMWebRTCSettings.sharedInstance
        participantMutedImageV.image = settings.iconMutedParticipant
        counterpartImage.image = settings.iconCounterpart
        pulse.image = settings.iconAvatar
        pipButton.setImage(settings.iconCollapse, for: .normal)
        pipButton.setImage(settings.iconExpand, for: .selected)
        view.backgroundColor = settings.backgroundColor
        callStatusLabel.textColor = settings.foregroundColor
        counterpartLabel.textColor = settings.foregroundColor
        videoStatusBottomView.backgroundColor = .clear
    }

    private let defaultValues = UserDefaults.standard
    var activeCall: ActiveCall?
    var joined: Bool = false
    public var initialState: PIPState = .full
    public var pipSize: CGSize { return CGSize(width: 200, height: 300)}
    var conferenceParticipants: [Participant] = []
    var outboundConversationId: String?
    private var transferIsOngoing = false
    var activeCallTracks: ActiveCallTracks = ActiveCallTracks()
    var callType: MMCallType = .audio
    var canScreenShare: Bool {
        return true
    }

    var canShowDialpad: Bool {
        return false
    }

    var isMuted: Bool {
        get {
            return videoStatusBottomView.mute.isSelected
        }
        set {
            if newValue { // user click on mute
                videoStatusBottomView.mute.isSelected = true
            } else { // user click on unmute
                videoStatusBottomView.mute.isSelected = false
                let semaphore = DispatchSemaphore(value: 0)
                MMCallController.checkMicPermission { [weak self] grant in
                    if grant {
                        self?.videoStatusBottomView.mute.isSelected = false
                    } else {
                        self?.videoStatusBottomView.mute.isSelected = true
                        self?.askForSystemSettings(
                            title: MMLoc.permissionNeeded,
                            description: MMLoc.microphonePermissionPermanentlyDenied
                        ) { success in
                            MMLogDebug("handled permission with success: \(success)")
                        }
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            }
        }
    }
    var isCameraFlipped: Bool = false
    var speakerphoneOn: Bool {
        get {
            return !videoStatusBottomView.speaker.isSelected
        }
        set {
            videoStatusBottomView.speaker.isSelected = !newValue
        }
    }
    var recording = false
    var pulseLayers = [CAShapeLayer]()
    var counterpart: String?
    var outboundFrom: String?
    var destinationName: String?
    var statusLabelTimer = Timer()
    var buttonsHidingTimer = Timer()
    @IBOutlet weak var localVideoView: UIView!
    @IBOutlet weak var remoteVideoViewConference: UIView!
    @IBOutlet weak var counterpartLabel: UILabel!
    @IBOutlet weak var pulse: UIImageView!
    @IBOutlet weak var counterpartImage: UIImageView!
    @IBOutlet weak var groupImage: UIImageView!
    @IBOutlet weak var callStatusLabel: UILabel!
    @IBOutlet weak var participantMutedImageV: UIImageView!
    @IBOutlet weak var networkStatusLabel: UILabel!
    @IBOutlet weak var videoStatusTopView: UIView!
    @IBOutlet weak var videoStatusBottomView: CallButtonStackView!
    @IBOutlet weak var pipButton: UIButton!
    
    var localView: UIView?
    var localViewFrame: CGRect?
    var remoteView: UIView?
    var remoteViewconference: UIView?
    var remoteViewFrameConference: CGRect?
    var ringbackPlayer: AVAudioPlayer?
    var player: AVAudioPlayer?
    var localNetworkQuality: NetworkQuality = NetworkQuality.excellent
    var remoteNetworkQuality: NetworkQuality = NetworkQuality.excellent
    var callEstablishedEvent: CallEstablishedEvent?
    private var isEstablishedMock: Bool = false
    private var isEstablished: Bool {
        get {
            return callEstablishedEvent != nil
        }
        set {
            isEstablishedMock = newValue
        }
    }

    public static var new: MMCallController {
        #if SWIFT_PACKAGE
            let storyboard = UIStoryboard(name: "MMCalls_SPM", bundle: .module)
        #else
            let storyboard = UIStoryboard(name: "MMCalls", bundle: MMWebRTCService.resourceBundle)
        #endif
        return storyboard.instantiateViewController(withIdentifier: "CallController") as! MMCallController
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        videoStatusBottomView.setupButtons()
        applySettings()
        hideCallRelatedViewElements()
        counterpartLabel.text = self.destinationName ?? self.counterpart
        callStatusLabel.text = String(format: MMLoc.calling, self.counterpart ?? "...")
        if activeCall != nil {
            handleIncomingCall()
        } else {
            performCall()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil)
        self.addTapGesture()
        NotificationCenter.default.addObserver(self, selector: #selector(self.deviceRotated), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    deinit {
        statusLabelTimer.invalidate()
        buttonsHidingTimer.invalidate()
        MMPopOverBar.hide() // in case a warning for "you are muted" is present
        stopRingback()
        stopPlayer()
        NotificationCenter.default.removeObserver(self)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let establishedEvent = callEstablishedEvent {
            onEstablished(establishedEvent)
        }
    }
    
    @objc private func deviceRotated() {
        DispatchQueue.main.async {
            self.setupLocalViewFrame()
            if PIPKit.isPIP {
                self.view.center = UIApplication.center
                self.setNeedsUpdatePIPFrame()
            }
        }
    }
    
    internal func isSpeakerphoneEnabled() -> Bool {
        return AVAudioSession.sharedInstance().currentRoute.outputs.contains { $0.portType == .builtInSpeaker }
    }

    @objc
    func handleRouteChange(_ notification: Notification) {
        guard
        let userInfo = notification.userInfo,
        let reasonRaw = userInfo[AVAudioSessionRouteChangeReasonKey] as? NSNumber,
        let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw.uintValue)
        else { fatalError("Strange... could not get routeChange") }
        switch reason {
        case .oldDeviceUnavailable:
            MMLogError("oldDeviceUnavailable")
        case .newDeviceAvailable:
            MMLogDebug("headset/line plugged in")
        case .routeConfigurationChange:
            MMLogDebug("headset pulled out")
        case .categoryChange, .override:
            // When category change means it went from system call UI to our callcontroller.
            // .override means something (ie speaker mode) changed.
            speakerphoneOn = isSpeakerphoneEnabled()
        default:
            MMLogDebug("not handling reason")
        }
    }
    
    var isVideoCall: Bool {
        return hasRemoteVideo || hasLocalVideo
    }
    
    internal func mustFinalizeCall() -> Bool {
        guard let activeCall = activeCall else {
            return true
        }
        
        switch activeCall {
        case .applicationCall(let applicationCall):
            return applicationCall.status == .finished || applicationCall.status == .finishing
        case .webRTCCall(let webRTCCall):
            return webRTCCall.status == .finished || webRTCCall.status == .finishing
        }
    }
    
    internal func handleApplicationCallError(_ error: CallError?) {
        switch error {
        case .applicationCallInProgress, .callInProgress:
            self.showErrorAlert(message: MMLoc.finishCurrentCall)
        case .invalidToken, .expiredToken, .invalidCustomData:
            self.showErrorAlert(message: MMLoc.badRequest)
        case .noInternetConnection:
            self.showErrorAlert(message: MMLoc.noInternetConnection)
        case .invalidDestination:
            self.showErrorAlert(message: MMLoc.userNotFoundDestination)
        case .missingMicrophonePermission:
            self.showErrorAlert(message: MMLoc.audioPermissionNotGranted)
        default:
            MMLogError("UI unfriendly Call Error, not displayed")
        }
        if mustFinalizeCall() {
            finalizeCallPreview(error?.localizedDescription ?? MMLoc.somethingWentWrong)
        }
    }
    
    internal func performApplicationCall(to destination: String, from outboundFrom: String) {
        // Not supported yet
    }

    internal func performCall() {
        // Not supported yet
    }

    
    func handleIncomingCall() {
        guard let activeCall = activeCall else { return }
        switch activeCall {
        case .applicationCall(let applicationCall):
            applicationCall.applicationCallEventListener = self
        case .webRTCCall(let webRTCCall):
            webRTCCall.webrtcCallEventListener = self
        }
        showActiveCallViewElements()
    }

    @IBAction func onPipTap(_ sender: Any) {
        for button in videoStatusBottomView.subviews {
            if button != videoStatusBottomView.hangup {
                button.isHidden =  !PIPKit.isPIP
            }
        }
        counterpartImage.isHidden = !PIPKit.isPIP
        counterpartLabel.isHidden = !PIPKit.isPIP
        pipButton.isSelected = !pipButton.isSelected
        if PIPKit.isPIP {
            stopPIPMode()
            handleMutePopover()
        } else {
            startPIPMode()
            hideVideoElements()
            MMPopOverBar.hide()
        }
        showActiveCallViewElements()
    }
    
    @IBAction func hangupCall(_ sender: Any) {
        self.stopPulse()
        
        guard let activeCall = activeCall else { return }
        
        switch activeCall {
        case .applicationCall(let applicationCall):
            applicationCall.hangup()
            CallKitManager.shared.localApplicationHangup(applicationCall.id())
        case .webRTCCall(let webRTCCall):
            webRTCCall.hangup()
            CallKitManager.shared.localHangup(webRTCCall.id())
        }
    }
    
    @IBAction func onScreenSharing(_ sender: Any) {
        guard let activeCall = activeCall else { return }

        do {
            let isSharing: Bool
            switch activeCall {
            case .applicationCall(let applicationCall):
                isSharing = applicationCall.hasScreenShare()
                try applicationCall.screenShare(screenShare: !isSharing)
            case .webRTCCall(let webRTCCall):
                isSharing = webRTCCall.hasScreenShare()
                try webRTCCall.screenShare(screenShare: !isSharing)
            }
            videoStatusBottomView.screenShare.isSelected = !isSharing
        } catch let error as CallError {
            showErrorAlert(message: error.localizedDescription)
        } catch {
            showErrorAlert(message: MMLoc.somethingWentWrong)
        }
    }
    
    internal func handleMutePopover() {
        if isMuted {
            let settings = MMWebRTCSettings.sharedInstance
            MMPopOverBar.show(
                backgroundColor: settings.backgroundColor,
                textColor: settings.foregroundColor,
                message: MMLoc.microphoneMuted,
                duration: 9999, // Don't use double(Int.max) because it overflows TimeInterval
                options: MMPopOverBar.Options(shouldConsiderSafeArea: true,
                                              isStretchable: true),
                completion: nil,
                presenterVC: self.parent ?? self)
        } else {
            MMPopOverBar.hide()
        }
    }

    internal func doApplyMuteValue() {
        guard let activeCall = activeCall else { return }
        do {
            switch activeCall {
            case .applicationCall(let applicationCall):
                let shouldMute = !applicationCall.muted()
                try applicationCall.mute(shouldMute)
                self.conferenceParticipants = applicationCall.participants()
                self.isMuted = applicationCall.muted()
            case .webRTCCall(let webRTCCall):
                let shouldMute = !webRTCCall.muted()
                try webRTCCall.mute(shouldMute)
                self.isMuted = webRTCCall.muted()
            }
            handleMutePopover()
        } catch let error as ApplicationCallError {
            self.showErrorAlert(message: error.description)
        } catch {
            self.showErrorAlert(message: error.localizedDescription)
        }
    }
    
    @IBAction func muteAudio(_ sender: Any) {
        doApplyMuteValue()
        if isVideoCall {
            self.hideVideoElements(delayed: true)
        }
    }
    
    internal func showErrorAlert(message: String?) {
        guard let message = message else { return }
        let settings = MMWebRTCSettings.sharedInstance
        MMPopOverBar.show(
            backgroundColor: settings.errorColor,
            textColor: settings.foregroundColor,
            message: message,
            duration: 3,
            options: MMPopOverBar.Options(shouldConsiderSafeArea: true,
                                          isStretchable: true),
            completion: nil,
            presenterVC: self.parent ?? self)
    }

    @IBAction func flipCamera(_ sender: UIButton) {
        self.isCameraFlipped = !isCameraFlipped
        
        if let activeCall = activeCall {
            switch activeCall {
            case .applicationCall(let applicationCall):
                applicationCall.cameraOrientation(
                    applicationCall.cameraOrientation() == .front ? .back : .front)
            case .webRTCCall(let webRTCCall):
                webRTCCall.cameraOrientation(
                    webRTCCall.cameraOrientation() == .front ? .back : .front)
            }
        }
        
        if isVideoCall {
            self.hideVideoElements(delayed: true)
        }
    }

    @IBAction func toggleSpeakerphone(_ sender: UIButton) {
        self.speakerphoneOn = !self.speakerphoneOn
        
        if let activeCall = activeCall {

            let onErrorCompletion: (Error?) -> Void = { error in
                DispatchQueue.main.async {
                    guard let error = error else { return }
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }

            switch activeCall {
            case .applicationCall(let applicationCall):
                applicationCall.speakerphone(speakerphoneOn, onErrorCompletion)
            case .webRTCCall(let webRTCCall):
                webRTCCall.speakerphone(speakerphoneOn, onErrorCompletion)
            }
        }


        if isVideoCall {
            self.hideVideoElements(delayed: true)
        }
    }

    internal func handleVideoElementsVisibility(_ hasLocalVideo: Bool) {
        DispatchQueue.main.async {
            self.videoStatusBottomView.localVideo.isSelected = hasLocalVideo
            if self.isVideoCall {
                self.hideVideoElements(delayed: true)
            }
        }
    }
    
    @IBAction func toggleVideo(_ sender: UIButton) {
        MMCallController.checkCamPermission() { [weak self] granted in
            if granted {
                let hasLocalVideo: Bool
                do {
                    if let activeCall = self?.activeCall {
                        switch activeCall {
                        case .applicationCall(let applicationCall):
                            hasLocalVideo = applicationCall.hasCameraVideo()
                            try applicationCall.cameraVideo(cameraVideo: !hasLocalVideo)
                        case .webRTCCall(let webRTCCall):
                            hasLocalVideo = webRTCCall.hasCameraVideo()
                            try webRTCCall.cameraVideo(cameraVideo: !hasLocalVideo)
                        }
                        self?.handleVideoElementsVisibility(!hasLocalVideo)
                    }
                } catch let error as CallError {
                    self?.showErrorAlert(message: error.localizedDescription)
                } catch {
                    self?.showErrorAlert(message: MMLoc.somethingWentWrong)
                }
            } else {
                self?.askForSystemSettings(
                    title: MMLoc.permissionNeeded,
                    description: MMLoc.cameraPermissionPermanentlyDenied
                ) { success in
                    MMLogDebug("handleFailure success: \(success)")
                }
            }
        }
    }

    internal func startCallDuration() {
        guard statusLabelTimer.isValid == false else { return }
        statusLabelTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: (#selector(self.updateCallStatusLabel)), userInfo: nil, repeats: true)
        statusLabelTimer.fire()
    }

    private func formatTimeString(from interval: Int) -> String {
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = (interval / (60*60)) % 60
        return hours > 0 ? String(format: "%02i:%02i:%02i", hours, minutes, seconds) :
        String(format: "%02i:%02i", minutes, seconds)
    }
    
    @objc private func updateCallStatusLabel() {
        var formattedTime = "0:00"

        if let activeCall = activeCall {
            formattedTime = formatTimeString(from: activeCall.duration)
        }
        
        self.callStatusLabel.text = formattedTime
    }

    private var conversationId: String? {
        let callCustomData = MobileMessaging.webRTCService?.notificationData?.customData
        // Incoming calls has customData, outbound ones has conversationId injected
        return outboundConversationId ?? (callCustomData?["conversationId"] as? String)
    }
    
    internal var isVideoStreaming: Bool {
        return localView != nil || remoteView != nil
    }
    
    internal var hasRemoteVideo: Bool {
        if activeCall != nil {
            return remoteView != nil
        }
        return false
    }
    
    internal var hasLocalVideo: Bool {
        if let activeCall = activeCall {
            switch activeCall {
            case .applicationCall(let applicationCall):
                return applicationCall.hasCameraVideo()
            case .webRTCCall(let webRTCCall):
                return webRTCCall.hasCameraVideo()
            }
        }
        return false
    }

    internal var callStatus: CallStatus {
        if let activeCall = activeCall {
            switch activeCall {
            case .applicationCall(let applicationCall):
                return applicationCall.status
            case .webRTCCall(let webRTCCall):
                return webRTCCall.status
            }
        }
        return .finished
    }
    
    private func nullifyComponents() {
        activeCall = nil
        activeCallTracks.activeVideoTrack = nil
        callEstablishedEvent = nil
        statusLabelTimer.invalidate()
        buttonsHidingTimer.invalidate()
        MobileMessaging.webRTCService?.notificationData = nil
    }
    
    internal func finalizeCallPreview(_ message: String) {
        MMLogDebug("finalizeCallPreview with message: \(message)")
        playDisconnectCall()
        statusLabelTimer.invalidate()
        self.stopPulse()
        if isVideoStreaming {
            self.finalizeVideoCallPreview()
        }
        
        if let activeCall = activeCall {
            switch activeCall {
            case .applicationCall(let applicationCall):
                CallKitManager.shared.endApplicationCall(applicationCall)
                applicationCall.applicationCallEventListener = nil
            case .webRTCCall(let webRTCCall):
                CallKitManager.shared.endWebRTCCall(webRTCCall)
                webRTCCall.webrtcCallEventListener = nil
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            PIPKit.dismiss(animated: true)
            self?.nullifyComponents()
        }
    }

    internal func startRingback() {
        if ringbackPlayer != nil {
            stopRingback()
        }
        if let assetdata = MobileMessaging.webRTCService?.settings.soundStartCall.data {
            do {
                // Use NSDataAsset's data property to access the audio file stored in Sound.
                ringbackPlayer = try AVAudioPlayer(data: assetdata)
                // Play the above sound file.
                ringbackPlayer?.currentTime = 0
                ringbackPlayer?.numberOfLoops = -1
                ringbackPlayer?.prepareToPlay()
                ringbackPlayer?.play()
            } catch {
                MMLogDebug("Error starting ringback tone")
            }
        } else {
            fatalError("Unable to find asset soundStartCall")
        }
    }

    internal func stopRingback() {
        ringbackPlayer?.stop()
        ringbackPlayer = nil
    }
    
    internal func stopPlayer() {
        player?.stop()
        player = nil
    }

    internal func playDisconnectCall() {
        if player != nil {
            stopPlayer()
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
}

#else
public class MMCallController: UIViewController {
    @IBOutlet weak var localVideoView: UIView!
    @IBOutlet weak var remoteVideoViewConference: UIView!
    @IBOutlet weak var counterpartLabel: UILabel!
    @IBOutlet weak var pulse: UIImageView!
    @IBOutlet weak var counterpartImage: UIImageView!
    @IBOutlet weak var groupImage: UIImageView!
    @IBOutlet weak var callStatusLabel: UILabel!
    @IBOutlet weak var participantMutedImageV: UIImageView!
    @IBOutlet weak var networkStatusLabel: UILabel!
    @IBOutlet weak var videoStatusTopView: UIView!
    @IBOutlet weak var videoStatusBottomView: UIView!
    @IBOutlet weak var pipButton: UIButton!
}
#endif

