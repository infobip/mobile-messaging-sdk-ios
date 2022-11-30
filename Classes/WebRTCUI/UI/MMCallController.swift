//
//  MMCallController.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 19/08/2021.
//  Copyright © 2021 Infobip Ltd. All rights reserved.
//

import UIKit
import InfobipRTC
import AVFoundation
import CallKit

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

    }

    private let defaultValues = UserDefaults.standard
    var activeApplicationCall: ApplicationCall?
    var joined: Bool = false
    public var initialState: PIPState = .full
    public var pipSize: CGSize { return CGSize(width: 200, height: 300)}
    var conferenceParticipants: [Participant] = []
    var outboundConversationId: String?
    private var transferIsOngoing = false
    internal var remoteCameraVideoTrack: VideoTrack?
    internal var remoteSharingVideoTrack: VideoTrack?
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
    var localNetworkQuality: NetworkQuality = NetworkQuality.EXCELLENT
    var remoteNetworkQuality: NetworkQuality = NetworkQuality.EXCELLENT
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

    static var new: MMCallController {
        let storyboard = UIStoryboard(name: "MMCalls", bundle: MMWebRTCService.resourceBundle)
       return storyboard.instantiateViewController(
       withIdentifier: "CallController") as! MMCallController
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        videoStatusBottomView.setupButtons()
        applySettings()
        hideCallRelatedViewElements()
        counterpartLabel.text = self.destinationName ?? self.counterpart
        callStatusLabel.text = String(format: MMLoc.calling, self.counterpart ?? "...")
        if activeApplicationCall != nil {
            handleIncomingApplicationCall()
        } else {
            performCall()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil)
        self.addTapGesture()
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
    
    internal func mustFinalizeApplicationCall() -> Bool {
        guard let activeApplicationCall = activeApplicationCall else {
            return true
        }
        return activeApplicationCall.status == .FINISHED || activeApplicationCall.status == .FINISHING
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
        if mustFinalizeApplicationCall() {
            finalizeCallPreview(error?.localizedDescription ?? MMLoc.somethingWentWrong)
        }
    }
    
    internal func performApplicationCall(to destination: String, from outboundFrom: String) {
        // Not supported yet
    }

    internal func performCall() {
        // Not supported yet
    }

    internal func handleIncomingCall() {
        self.showActiveCallViewElements()
    }
    
    internal func handleIncomingApplicationCall() {
        self.activeApplicationCall?.applicationCallEventListener = self
        self.showActiveCallViewElements()
    }

    func startApplicationCall(_ applicationId: String, _ isMuted: Bool,
                              _ completion: @escaping (CallConversationsApplicationRequest?, String?) -> Void) {
        // Not supported yet
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
        if let activeApplicationCall = self.activeApplicationCall {
            activeApplicationCall.hangup()
            CallKitManager.shared.localHangup(activeApplicationCall.id())
        }
    }
    
    @IBAction func onScreenSharing(_ sender: Any) {
        if let activeApplicationCall = self.activeApplicationCall {
            let isSharing = activeApplicationCall.hasScreenShare()
            do {
                try activeApplicationCall.screenShare(screenShare: !isSharing)
                videoStatusBottomView.screenShare.isSelected = !isSharing
            } catch let error as CallError {
                showErrorAlert(message: error.localizedDescription)
            } catch {
                showErrorAlert(message: "Something unexpected happened")
            }
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
                presenterVC: self)
        } else {
            MMPopOverBar.hide()
        }
    }

    internal func doApplyMuteValue() {
        if let activeApplicationCall = self.activeApplicationCall {
            let shouldMute = !activeApplicationCall.muted()
            do {
                try activeApplicationCall.mute(shouldMute)
                handleMutePopover()
                self.conferenceParticipants = activeApplicationCall.participants()
            } catch let error as ApplicationCallError {
                self.showErrorAlert(message: error.description)
            } catch {
                self.showErrorAlert(message: error.localizedDescription)
            }
        }
    }
    
    @IBAction func muteAudio(_ sender: Any) {
        self.isMuted = !self.isMuted
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
            presenterVC: self)
    }

    @IBAction func flipCamera(_ sender: UIButton) {
        self.isCameraFlipped = !isCameraFlipped
        if let activeApplicationCall = self.activeApplicationCall { // ??
            activeApplicationCall.cameraOrientation(
                activeApplicationCall.cameraOrientation() == .front ? .back : .front)
        }
        
        if isVideoCall {
            self.hideVideoElements(delayed: true)
        }
    }

    @IBAction func toggleSpeakerphone(_ sender: UIButton) {
        self.speakerphoneOn = !self.speakerphoneOn
        if let activeApplicationCall = self.activeApplicationCall {
            activeApplicationCall.speakerphone(speakerphoneOn) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.showErrorAlert(message: error.localizedDescription)
                    }
                }
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
                var hasLocalVideo = false
                if let activeApplicationCall = self?.activeApplicationCall {
                    hasLocalVideo = activeApplicationCall.hasCameraVideo()
                    do {
                        try activeApplicationCall.cameraVideo(cameraVideo: !hasLocalVideo)
                        self?.handleVideoElementsVisibility(!hasLocalVideo)
                    } catch let error as CallError {
                        self?.showErrorAlert(message: error.localizedDescription)
                    } catch {
                        self?.showErrorAlert(message: "Something unexpected happened")
                    }
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

    @objc private func updateCallStatusLabel() {
        var durationInSeconds: Int = 0
        if let activeApplicationCall = self.activeApplicationCall {
            durationInSeconds = activeApplicationCall.duration()
        } else {
            durationInSeconds = 0
        }

        let minutes = durationInSeconds / 60 % 60
        let seconds = durationInSeconds % 60
        self.callStatusLabel.text = String(format: "%02i:%02i", minutes, seconds)
    }

    private var conversationId: String? {
        let callCustomData = MobileMessaging.webrtcService?.notificationData?.customData
        // Incoming calls has customData, outbound ones has conversationId injected
        return outboundConversationId ?? (callCustomData?["conversationId"] as? String)
    }
    
    internal var isVideoStreaming: Bool {
        return localView != nil || remoteView != nil
    }
    
    internal var hasRemoteVideo: Bool {
        if activeApplicationCall != nil {
            return remoteView != nil
        }
        return false
    }
    
    internal var hasLocalVideo: Bool {
        if let applicationCall = activeApplicationCall {
            return applicationCall.hasCameraVideo()
        }
        return false
    }

    internal var callStatus: CallStatus {
        if let applicationCall = activeApplicationCall {
            return applicationCall.status
        }
        return .FINISHED
    }
    
    private func nullifyComponents() {
        activeApplicationCall = nil
        remoteCameraVideoTrack = nil
        remoteSharingVideoTrack = nil
        callEstablishedEvent = nil
        statusLabelTimer.invalidate()
        buttonsHidingTimer.invalidate()
        MobileMessaging.webrtcService?.notificationData = nil
    }
    
    internal func finalizeCallPreview(_ message: String) {
        MMLogDebug("finalizeCallPreview with message: \(message)")
        playDisconnectCall()
        statusLabelTimer.invalidate()
        self.stopPulse()
        if isVideoStreaming {
            self.finalizeVideoCallPreview()
        }
        if let applicationCall = self.activeApplicationCall {
            CallKitManager.shared.endApplicationCall(applicationCall)
            self.activeApplicationCall?.applicationCallEventListener = nil
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
        if let assetdata = MobileMessaging.webrtcService?.settings.soundStartCall.data {
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
        if let assetdata = MobileMessaging.webrtcService?.settings.soundEndCall.data {
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
