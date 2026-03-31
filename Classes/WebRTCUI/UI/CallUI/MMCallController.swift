//
//  MMCallController.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import UIKit
import SwiftUI
import AVFoundation

#if WEBRTCUI_ENABLED
import InfobipRTC
import InfobipMobileUI

// MARK: - Public button action API (unchanged)

public enum MMCallButtonsAction: Equatable {

    public static func == (lhs: MMCallButtonsAction, rhs: MMCallButtonsAction) -> Bool {
        switch (lhs, rhs) {
        case (.hangup, .hangup): return true
        case (.screenshare, .screenshare): return true
        case (.microphone, .microphone): return true
        case (.video, .video): return true
        case (.flipCamera, .flipCamera): return true
        case (.speakerphone, .speakerphone): return true
        case (.custom(_), .custom(_)): return true
        default: return false
        }
    }

    case hangup
    case screenshare((() -> Void)? = nil)
    case microphone((() -> Void)? = nil)
    case video((() -> Void)? = nil)
    case flipCamera((() -> Void)? = nil)
    case speakerphone((() -> Void)? = nil)
    case custom(MMCallButtonModel)
}

public struct MMCallButtonModel {
    public var icon: UIImage?
    public var iconSelected: UIImage?
    public var color: UIColor
    public var selectedColor: UIColor?
    public var text: String?
    public var action: (UIButton) -> Void

    public init(
        icon: UIImage?,
        iconSelected: UIImage? = nil,
        color: UIColor,
        selectedColor: UIColor? = nil,
        text: String? = nil,
        action: @escaping (UIButton) -> Void
    ) {
        self.icon = icon
        self.iconSelected = iconSelected
        self.color = color
        self.selectedColor = selectedColor
        self.text = text
        self.action = action
    }
}

// MARK: - MMCallController

public class MMCallController: UIViewController, IBPIPUsable {

    // MARK: - Public (IBPIPUsable)

    public var isInitiatedWithPIP: Bool = false
    public var initialState: IBPIPState = .full

    public var pipSize: CGSize {
        callViewController?.pipSize ?? CGSize(width: 290, height: 180)
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Internal

    let interactor = CallInteractor()
    lazy var eventListener = CallControllerEventListenerImpl(controller: self)
    lazy var callEventListener = MMCallEventListener(controller: eventListener)

    var uiState = IBCallUIState()
    private var buttons: [IBCallButtonModel] = []
    private var callViewController: IBCallViewController?
    private var callDurationTimer: Timer?

    private var defaultActions: [MMCallButtonsAction] {
        if MMWebRTCSettings.sharedInstance.customButtons.isEmpty {
            return [.hangup, .microphone(), .screenshare(), .video(), .speakerphone()]
        }
        return MMWebRTCSettings.sharedInstance.customButtons
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MMWebRTCSettings.sharedInstance.backgroundColor
        setupButtons(from: defaultActions)
        embedCallViewController()
        interactor.showErrorAlert = { [weak self] message in
            self?.showErrorAlert(message: message)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appMovedToForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        uiState.isPIP = IBPIPKit.isActive && IBPIPKit.isPIP
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if #available(iOS 16.0, *) {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
    }

    // MARK: - Setup

    private func embedCallViewController() {
        let s = MMWebRTCSettings.sharedInstance
        let config = IBCallUIConfiguration(
            backgroundColor: Color(s.backgroundColor),
            foregroundColor: Color(s.foregroundColor),
            textSecondaryColor: Color(s.textSecondaryColor),
            sheetBackgroundColor: Color(s.sheetBackgroundColor),
            sheetDividerColor: Color(s.sheetDividerColor),
            sheetDragIndicatorColor: Color(s.sheetDragIndicatorColor),
            buttonColor: Color(s.buttonColor),
            buttonSelectedColor: Color(s.buttonColorSelected),
            hangupButtonColor: Color(s.hangUpButtonColor),
            errorColor: Color(s.errorColor),
            rowActionLabelColor: Color(s.rowActionLabelColor),
            iconMute: Image(uiImage: s.iconMute ?? UIImage()),
            iconUnMute: Image(uiImage: s.iconUnMute ?? UIImage()),
            iconMutedParticipant: Image(uiImage: s.iconMutedParticipant ?? UIImage()),
            iconScreenShareOn: Image(uiImage: s.iconScreenShareOn ?? UIImage()),
            iconScreenShareOff: Image(uiImage: s.iconScreenShareOff ?? UIImage()),
            iconAvatar: Image(uiImage: s.iconAvatar ?? UIImage()),
            iconVideo: Image(uiImage: s.iconVideo ?? UIImage()),
            iconVideoOff: Image(uiImage: s.iconVideoOff ?? UIImage()),
            iconSpeaker: Image(uiImage: s.iconSpeaker ?? UIImage()),
            iconSpeakerOff: Image(uiImage: s.iconSpeakerOff ?? UIImage()),
            iconFlipCamera: Image(uiImage: s.iconFlipCamera ?? UIImage()),
            iconEndCall: Image(uiImage: s.iconEndCall ?? UIImage()),
            iconExpand: Image(uiImage: s.iconExpand ?? UIImage()),
            iconCollapse: Image(uiImage: s.iconCollapse ?? UIImage()),
            iconAlert: Image(uiImage: s.iconAlert ?? UIImage()),
            iconLandscapeOn: Image(uiImage: s.landscapeOnIcon ?? UIImage()),
            iconLandscapeOff: Image(uiImage: s.landscapeOffIcon ?? UIImage())
        )

        let rendererFactory: (AnyObject) -> UIView = { track in
            let view = InfobipRTCFactory.videoView(frame: .zero, contentMode: .scaleAspectFill)
            (track as? VideoTrack)?.addRenderer(view)
            return view
        }

        let vc = IBCallViewController(
            state: uiState,
            buttons: buttons,
            configuration: config,
            rendererFactory: rendererFactory
        )
        vc.initialState = .full
        vc.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(vc)
        view.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vc.view.topAnchor.constraint(equalTo: view.topAnchor),
            vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        vc.didMove(toParent: self)
        callViewController = vc
    }

    // MARK: - Button building

    private func setupButtons(from actions: [MMCallButtonsAction]) {
        var actions = actions
        if actions.first != .hangup {
            actions.removeAll { $0 == .hangup }
            actions.insert(.hangup, at: 0)
        }
        buttons = actions.enumerated().map { ( _, action) in
            return buildButton(for: action)
        }
    }

    func buildButton(for action: MMCallButtonsAction) -> IBCallButtonModel {
        let s = MMWebRTCSettings.sharedInstance
        switch action {
        case .hangup:
            return IBCallButtonModel(
                id: "hangup",
                icon: Image(uiImage: s.iconEndCall ?? UIImage()),
                backgroundColor: Color(s.hangUpButtonColor),
                isSelected: false,
                isEnabled: true,
                onTap: { [weak self] in self?.hangup() }
            )
        case .screenshare(let completion):
            return IBCallButtonModel(
                id: "screenshare",
                icon: Image(uiImage: s.iconScreenShareOn ?? UIImage()),
                selectedIcon: Image(uiImage: s.iconScreenShareOff ?? UIImage()),
                label: MMLoc.screenShare,
                backgroundColor: Color(s.buttonColor),
                selectedBackgroundColor: Color(s.buttonColorSelected),
                isSelected: false,
                isEnabled: true,
                onTap: { [weak self] in
                    guard let self else { return }
                    if let isSharing = self.interactor.screenShareToggle() {
                        self.setButton(id: "screenshare", selected: !isSharing)
                    }
                    completion?()
                }
            )
        case .microphone(let completion):
            return IBCallButtonModel(
                id: "microphone",
                icon: Image(uiImage: s.iconMute ?? UIImage()),
                selectedIcon: Image(uiImage: s.iconUnMute ?? UIImage()),
                label: "Microphone",
                backgroundColor: Color(s.buttonColorSelected),
                selectedBackgroundColor: Color(s.buttonColor),
                isSelected: false,
                isEnabled: true,
                onTap: { [weak self] in
                    CallInteractor.checkMicPermission { granted in
                        self?.interactor.micToggle { isMuted, permitted in
                            DispatchQueue.mmEnsureMain {
                                self?.setButton(id: "microphone", selected: isMuted, enabled: permitted)
                                self?.handleMutePopover()
                            }
                        }
                    }
                    completion?()
                }
            )
        case .video(let completion):
            return IBCallButtonModel(
                id: "video",
                icon: Image(uiImage: s.iconVideoOff ?? UIImage()),
                selectedIcon: Image(uiImage: s.iconVideo ?? UIImage()),
                label: "Video",
                backgroundColor: Color(s.buttonColor),
                selectedBackgroundColor: Color(s.buttonColorSelected),
                isSelected: false,
                isEnabled: true,
                onTap: { [weak self] in
                    guard let self else { return }
                    self.interactor.videoToggle { [weak self] isActive, permitted in
                        guard let self else { return }
                        DispatchQueue.main.async {
                            self.setButton(id: "video", selected: isActive, enabled: permitted)
                            if !permitted {
                                self.showErrorAlert(message: MMLoc.cameraPermissionPermanentlyDenied)
                            }
                            // Add/remove flip-camera button dynamically
                            let flipModel = IBCallButtonModel(
                                id: "flipCamera",
                                icon: Image(uiImage: s.iconFlipCamera ?? UIImage()),
                                label: MMLoc.flipCamera,
                                backgroundColor: Color(s.buttonColor),
                                selectedBackgroundColor: Color(s.buttonColorSelected),
                                isSelected: false,
                                isEnabled: true,
                                onTap: { [weak self] in self?.interactor.flipCamera() }
                            )
                            if isActive {
                                if !self.buttons.contains(where: { $0.id == "flipCamera" }) {
                                    self.buttons.append(flipModel)
                                }
                            } else {
                                self.buttons.removeAll { $0.id == "flipCamera" }
                            }
                            self.callViewController?.updateButtons(self.buttons)
                        }
                    }
                    completion?()
                }
            )
        case .flipCamera(let completion):
            return IBCallButtonModel(
                id: "flipCamera",
                icon: Image(uiImage: s.iconFlipCamera ?? UIImage()),
                label: MMLoc.flipCamera,
                backgroundColor: Color(s.buttonColor),
                selectedBackgroundColor: Color(s.buttonColorSelected),
                isSelected: false,
                isEnabled: true,
                onTap: { [weak self] in
                    self?.interactor.flipCamera()
                    completion?()
                }
            )
        case .speakerphone(let completion):
            return IBCallButtonModel(
                id: "speakerphone",
                icon: Image(uiImage: s.iconSpeakerOff ?? UIImage()),
                selectedIcon: Image(uiImage: s.iconSpeaker ?? UIImage()),
                label: MMLoc.speaker,
                backgroundColor: Color(s.buttonColor),
                selectedBackgroundColor: Color(s.buttonColorSelected),
                isSelected: false,
                isEnabled: true,
                onTap: { [weak self] in
                    self?.interactor.toggleSpeakerphone { result in
                        guard let result, let self = self else { return }
                        self.setButton(id: "speakerphone", selected: result)
                    }
                    completion?()
                }
            )
        case .custom(let mm):
            return IBCallButtonModel(
                id: "custom-\(UUID().uuidString)",
                icon: Image(uiImage: mm.icon ?? UIImage()),
                selectedIcon: mm.iconSelected.map { Image(uiImage: $0) },
                label: mm.text,
                backgroundColor: Color(mm.color),
                selectedBackgroundColor: mm.selectedColor.map(Color.init),
                isSelected: false,
                isEnabled: true,
                onTap: { mm.action(UIButton()) }
            )
        }
    }

    // MARK: - Button state helpers

    func setButton(id: String, selected: Bool, enabled: Bool = true) {
        guard let idx = buttons.firstIndex(where: { $0.id == id }) else { return }
        buttons[idx].isSelected = selected
        buttons[idx].isEnabled = enabled
        callViewController?.updateButtons(buttons)
    }

    // MARK: - Timer

    func startCallTimer() {
        guard callDurationTimer == nil else { return }
        uiState.statusText = interactor.getFormattedCallDuration()
        callDurationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.uiState.statusText = self.interactor.getFormattedCallDuration()
            }
        }
    }

    func stopCallTimer() {
        callDurationTimer?.invalidate()
        callDurationTimer = nil
    }

    // MARK: - Actions

    func hangup() {
        stopCallTimer()
        interactor.hangup()
        interactor.playDisconnectCall()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            if self.isInitiatedWithPIP {
                IBPIPKit.dismiss(animated: true)
            } else {
                self.dismiss(animated: true)
            }
        }
        interactor.reconnectingPlayer.cleanPlayer()
    }

    @MainActor
    func didStartReconnecting(_ value: Bool) {
        if value {
            self.uiState.callPhase = .reconnecting
            self.interactor.reconnectingPlayer.startReconnecting()
        } else {
            self.uiState.callPhase = .established
            self.interactor.reconnectingPlayer.reconnected()
            self.handleMutePopover()
        }
    }

    func handleMutePopover(with animation: Bool = true) {
        guard let currentCall = interactor.currentCall else { return }
        let isMuted = currentCall.isMuted
        if isMuted && !IBPIPKit.isPIP {
            let settings = MMWebRTCSettings.sharedInstance
            MMPopOverBar.show(
                textColor: settings.foregroundColor,
                backgroundColor: settings.errorColor,
                icon: settings.iconAlert,
                iconTint: settings.foregroundColor,
                message: MMLoc.microphoneMuted,
                duration: 9999,
                hideOnTap: false,
                options: MMPopOverBar.Options(shouldConsiderSafeArea: false, isStretchable: true),
                completion: nil,
                presenterVC: self)
        } else {
            MMPopOverBar.hide(with: animation)
        }
    }

    func showErrorAlert(message: String?) {
        guard let message else { return }
        MMPopOverBar.show(
            textColor: MMWebRTCSettings.sharedInstance.foregroundColor,
            backgroundColor: MMWebRTCSettings.sharedInstance.backgroundColor,
            icon: MMWebRTCSettings.sharedInstance.iconAlert,
            iconTint: MMWebRTCSettings.sharedInstance.foregroundColor,
            message: message,
            duration: 3,
            options: MMPopOverBar.Options(shouldConsiderSafeArea: false, isStretchable: true),
            completion: nil,
            presenterVC: self)
    }

    // MARK: - IBPIPUsable callbacks

    public func didChangedState(_ state: IBPIPState) {
        uiState.isPIP = (state == .pip)
        if state == .full {
            MobileMessaging.application.visibleViewController?.view.endEditing(true)
        }
    }

    // MARK: - Foreground observation

    @objc private func appMovedToForeground() {
        interactor.muteOnSystem()
        handleMutePopover(with: false)
        // Sync microphone button state
        let isMuted = interactor.currentCall?.isMuted ?? false
        setButton(id: "microphone", selected: isMuted)
    }

    // MARK: - Orientation

    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if #available(iOS 16.0, *) { return .all } else { return .portrait }
    }

    public override var shouldAutorotate: Bool {
        if #available(iOS 16.0, *) { return true } else { return false }
    }
}

#endif
