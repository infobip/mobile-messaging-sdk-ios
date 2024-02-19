//
//  CallController.swift
//  MobileMessaging
//
//  Created by Maksym Svitlovskyi on 18/09/2023.
//

import UIKit
import AVFoundation

#if WEBRTCUI_ENABLED

private let topConstraintConstant: CGFloat = 48

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
    
    internal func makeVisibleButtonModel() -> VisibleCallButtonContent {
        return .init(
            icon: icon,
            iconSelected: iconSelected,
            backgroundColor: color,
            selectedBackgroundColor: selectedColor,
            action: action
        )
    }
    
    internal func makeListOptionButtonModel() -> HiddenCallButtonContent {
        return .init(icon: icon, iconSelected: iconSelected, text: text ?? "", action: action)
    }
}

public class MMCallController: UIViewController, MMPIPUsable {
    
    struct Constants {
        static let pipRegularSize: CGSize = CGSize(width: 200, height: 300)
        static let visibleButtonsMaxCount = 4
    }
    
    let callView = CallView()
    let interactor = CallInteractor()
    
    public var isInitiatedWithPIP: Bool = false

    lazy var eventListener = CallControllerEventListenerImpl(controller: self)
    lazy var callEventListener = MMCallEventListener(controller: eventListener)
    
    public var pipSize: CGSize {
        if callView.state.callState == .audioCall || callView.state.callState == .calling {
            return CGSize(width: self.callView.visibleButtonsView.contentStack.frame.width + 40, height: 180)
        }
        return Constants.pipRegularSize
    }
    public var initialState: PIPState = .full
    
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    var screenshareButtonContent: CallViewButtonContent?

    lazy var topConstraint: NSLayoutConstraint = callView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
    
    private var defaultButtons: [MMCallButtonsAction] {
        if MMWebRTCSettings.sharedInstance.customButtons.isEmpty {
            return [.hangup, .microphone(), .screenshare(), .video(), .speakerphone()]
        }
        return MMWebRTCSettings.sharedInstance.customButtons
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        
        setupWithButtons(defaultButtons)
        setupViewActions()

        view.backgroundColor = MMWebRTCSettings.sharedInstance.backgroundColor
        
        interactor.showErrorAlert = { [weak self] message in
            self?.showErrorAlert(message: message)
        }
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        callView.voiceCallView.collapseButton.isHidden = PIPKit.state == .none
        callView.mediaView.header.collapseButton.isHidden = PIPKit.state == .none

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
    
    func setupView() {
        callView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(callView)
        NSLayoutConstraint.activate([
            callView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            callView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            callView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            topConstraint
        ])
    }
    
    func setupWithButtons(_ actions: [MMCallButtonsAction]) {
        var actions = actions
        if actions.first != .hangup {
            if let index = actions.firstIndex(where: { $0 == .hangup }) {
                actions.remove(at: index)
            }
            actions.insert(.hangup, at: 0)
        }
        
        let visibleButtons: [VisibleCallButtonContent] = actions.enumerated().compactMap { (index, action) in
            if index < Constants.visibleButtonsMaxCount {
                let button = self.buildButton(for: action)
                let model = button.makeVisibleButtonModel()
                if case .screenshare = action {
                    self.screenshareButtonContent = model
                }
                return model
            }
            return nil
        }
        
        let hiddenButtons: [HiddenCallButtonContent] = actions.enumerated().compactMap { (index, action) in
            if index >= Constants.visibleButtonsMaxCount {
                let button = self.buildButton(for: action)
                let model = button.makeListOptionButtonModel()
                if case .screenshare = action {
                    self.screenshareButtonContent = model
                }
                return model
            }
            return nil
        }
        
        callView.hiddenButtonsView.setCell(with: hiddenButtons)
        callView.visibleButtonsView.setButtons(content: visibleButtons)
    }
    
    func setupViewActions() {
        callView.rootSheetView.setState(.mediumContent)
        
        callView.onPipTap = { [weak self] in
            self?.onPIPTap()
        }
        
        callView.onTimerRefresh = { [weak self] in
            return self?.interactor.getFormattedCallDuration() ?? "00:00"
        }
        
        callView.mediaView.onStopScreenshareTap = { [weak self] in
            if let result = self?.interactor.screenShareToggle(),
               let button = self?.screenshareButtonContent?.button {
                button.isSelected = !result
            }
        }
    }
    
    func showErrorAlert(message: String?) {
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
    
    func hangup() {
        interactor.hangup()
        interactor.playDisconnectCall()
        callView.callDurationTimer = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            if self.isInitiatedWithPIP {
                PIPKit.dismiss(animated: true)
            } else {
                self.dismiss(animated: true)
            }
        }
        interactor.reconnectingPlayer.cleanPlayer()
    }
    
    func onPIPTap() {
        if PIPKit.isPIP {
            stopPIPMode()
            handleMutePopover(with: false)
        } else {
            startPIPMode()
            handleMutePopover(with: false)
        }
    }
    
    internal func handleMutePopover(with animation: Bool = true) {
        guard let currentCall = interactor.currentCall else { return }
        if currentCall.isMuted && !PIPKit.isPIP {
            
            UIView.animate(withDuration: animation ? 0.2 : 0, animations: { [weak self] in
                self?.topConstraint.constant = topConstraintConstant
                self?.view.layoutIfNeeded()
            })
            
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
            UIView.animate(withDuration: animation ? 0.2 : 0, animations: { [weak self] in
                self?.topConstraint.constant = 0
                self?.view.layoutIfNeeded()
            })
            MMPopOverBar.hide(with: animation)
        }
    }
    
    func didStartReconnecting(_ value: Bool) {
        MMPopOverBar.hide()
        if value {
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                self?.topConstraint.constant = topConstraintConstant
                self?.view.layoutIfNeeded()
            })

            let settings = MMWebRTCSettings.sharedInstance
            MMPopOverBar.show(
                backgroundColor: settings.backgroundColor,
                textColor: settings.foregroundColor,
                message: MMLoc.connectionProblems,
                duration: 9999, // Don't use double(Int.max) because it overflows TimeInterval
                options: MMPopOverBar.Options(shouldConsiderSafeArea: true,
                                              isStretchable: true),
                completion: nil,
                presenterVC: self.parent ?? self)
            interactor.reconnectingPlayer.startReconnecting()
        } else {
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                self?.topConstraint.constant = 0
                self?.view.layoutIfNeeded()
            })
            interactor.reconnectingPlayer.reconnected()
            MMPopOverBar.hide(with: true)
            handleMutePopover()
        }
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if PIPKit.isPIP {
            self.view.center = UIApplication.center
            self.setNeedsUpdatePIPFrame()
        }
    }
}

extension MMCallController {
    func buildButton(for action: MMCallButtonsAction) -> MMCallButtonModel {
        switch action {
        case .hangup:
            return MMCallButtonModel(
                icon: MMWebRTCSettings.sharedInstance.iconEndCall,
                color: MMWebRTCSettings.sharedInstance.hangUpButtonColor,
                action: { [weak self] _ in
                    self?.hangup()
                }
            )
        case .screenshare(let completion):
            return MMCallButtonModel(
                icon: MMWebRTCSettings.sharedInstance.iconScreenShareOn,
                iconSelected: MMWebRTCSettings.sharedInstance.iconScreenShareOff,
                color: MMWebRTCSettings.sharedInstance.buttonColor,
                selectedColor: MMWebRTCSettings.sharedInstance.buttonColorSelected,
                text: "Screensharing",
                action: { [weak self] button in
                    let toggleResult = self?.interactor.screenShareToggle()
                    if let toggleResult = toggleResult {
                        button.isSelected = !toggleResult
                    }
                    completion?()
                }
            )
        case .microphone(let completion):
            return MMCallButtonModel(
                icon: MMWebRTCSettings.sharedInstance.iconMute,
                iconSelected: MMWebRTCSettings.sharedInstance.iconUnMute,
                color: MMWebRTCSettings.sharedInstance.buttonColorSelected,
                selectedColor: MMWebRTCSettings.sharedInstance.buttonColor,
                text: "Microphone",
                action: { [weak self] in
                    if let result = self?.interactor.micToggle() {
                        $0.isSelected = result
                        self?.handleMutePopover()
                    }
                    completion?()
                }
            )
        case .video(let completion):
            return MMCallButtonModel(
                icon: MMWebRTCSettings.sharedInstance.iconVideoOff,
                iconSelected: MMWebRTCSettings.sharedInstance.iconVideo,
                color: MMWebRTCSettings.sharedInstance.buttonColor,
                selectedColor: MMWebRTCSettings.sharedInstance.buttonColorSelected,
                text: "Video",
                action: { [weak self] button in
                    
                    self?.interactor.videoToggle(completion: { toggleResult in
                        DispatchQueue.main.async {
                            button.isSelected = toggleResult
                            
                            let cell = HiddenCallButtonContent(
                                icon: MMWebRTCSettings.sharedInstance.iconFlipCamera,
                                text: MMLoc.flipCamera,
                                action: { [weak self] _ in
                                    self?.interactor.flipCamera()
                                })
                            
                            if toggleResult {
                                self?.callView.hiddenButtonsView.addCell(with: cell)
                            } else {
                                self?.callView.hiddenButtonsView.removeCell(with: cell)
                            }
                        }
                    })
                    completion?()
                }
            )
        case .flipCamera(let completion):
            return MMCallButtonModel(
                icon: MMWebRTCSettings.sharedInstance.iconFlipCamera,
                iconSelected: nil,
                color: MMWebRTCSettings.sharedInstance.buttonColor,
                selectedColor: MMWebRTCSettings.sharedInstance.buttonColorSelected,
                text: "Camera Flip",
                action: { [weak self] button in
                    self?.interactor.flipCamera()
                    completion?()
                }
            )
        case .speakerphone(let completion):
            return MMCallButtonModel(
                icon: MMWebRTCSettings.sharedInstance.iconSpeakerOff,
                iconSelected: MMWebRTCSettings.sharedInstance.iconSpeaker,
                color: MMWebRTCSettings.sharedInstance.buttonColor,
                selectedColor: MMWebRTCSettings.sharedInstance.buttonColorSelected,
                text: "Speakerphone",
                action: { [weak self] button in
                    self?.interactor.toggleSpeakerphone(completion: { result in
                        guard let result = result else { return }
                        button.isSelected = result
                    })
                    completion?()
                }
            )
        case .custom(let callButtonModel):
            return callButtonModel
        }
    }
}
#endif
