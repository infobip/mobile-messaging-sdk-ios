//
//  CallView.swift
//  MobileMessaging
//
//  Created by Maksym Svitlovskyi on 26/09/2023.
//
import Foundation
#if WEBRTCUI_ENABLED
import InfobipRTC

class CallViewState {
    var title: String = ""
    var isRemoteMuted: Bool = false
    var callState: CallState = .audioCall
}

class MediaCallState {
    private(set) var localVideo: VideoTrack?
    private(set) var remoteVideo: VideoTrack?
    private(set) var anyScreenshare: Screenshare?
    
    enum Screenshare: Equatable {
        case local(VideoTrack), remote(VideoTrack)
    }

    deinit {
        anyScreenshare = nil
        localVideo = nil
        remoteVideo = nil
    }

    func isTracksEmpty() -> Bool {
        if localVideo == nil && remoteVideo == nil && anyScreenshare == nil {
            return true
        }
        return false
    }
    
    func isOnlyLocalVideoStream() -> Bool {
        if localVideo != nil && remoteVideo == nil && anyScreenshare == nil {
            return true
        }
        return false
    }
    
    func isAllTrackAvailable() -> Bool  {
        return localVideo != nil && remoteVideo != nil && anyScreenshare != nil
    }
    
    func updateTracks(with mediaTrack: MediaTrack) {
        switch mediaTrack {
        case .localVideo(let videoTrack):
            self.localVideo = videoTrack
        case .remoteVideo(let videoTrack):
            self.remoteVideo = videoTrack
        case .localScreenshare(let videoTrack):
            if let videoTrack = videoTrack {
                self.anyScreenshare = .local(videoTrack)
            } else {
                guard let anyScreenshare = anyScreenshare else { return }
                switch anyScreenshare {
                case .local(_):  self.anyScreenshare = nil
                case .remote(_):
                    return
                }
            }
        case .remoteScreenshare(let videoTrack):
            if let videoTrack = videoTrack {
                self.anyScreenshare = .remote(videoTrack)
            } else {
                guard let anyScreenshare = anyScreenshare else { return }
                switch anyScreenshare {
                case .local(_): return
                case .remote(_): self.anyScreenshare = nil
                }
            }
        }
    }
}

enum MediaTrack {
    case localVideo(VideoTrack?)
    case remoteVideo(VideoTrack?)
    case localScreenshare(VideoTrack?)
    case remoteScreenshare(VideoTrack?)
}

enum CallState: Equatable {
    case calling
    case audioCall
    case mediaCall(MediaCallState)
    
    static func == (lhs: CallState, rhs: CallState) -> Bool {
        switch (lhs, rhs) {
        case (.calling, .calling): return true
        case (.audioCall, .audioCall): return true
        case (.mediaCall(let lhsState), .mediaCall(let rhsState)): return lhsState === rhsState
        default: return false
        }
    }
}

protocol CallViewButtonContent {
    var button: UIButton? { get set }
}

class HiddenCallButtonContent: CallViewButtonContent, Equatable {
    var icon: UIImage?
    var iconSelected: UIImage?
    var text: String
    var action: (UIButton) -> Void
    
    weak var button: UIButton?
    
    init(icon: UIImage? = nil, iconSelected: UIImage? = nil, text: String, action: @escaping (UIButton) -> Void) {
        self.icon = icon
        self.iconSelected = iconSelected
        self.text = text
        self.action = action
    }
    
    static func == (lhs: HiddenCallButtonContent, rhs: HiddenCallButtonContent) -> Bool {
        lhs.icon == rhs.icon && lhs.iconSelected == rhs.iconSelected && lhs.text == rhs.text
    }
}


class VisibleCallButtonContent: CallViewButtonContent {
    var icon: UIImage?
    var iconSelected: UIImage?
    
    var backgroundColor: UIColor
    var selectedBackgroundColor: UIColor?
    var action: (UIButton) -> Void

    weak var button: UIButton?
    
    internal init(
        icon: UIImage? = nil,
        iconSelected: UIImage? = nil,
        backgroundColor: UIColor,
        selectedBackgroundColor: UIColor? = nil,
        action: @escaping (UIButton) -> Void
    ) {
        self.icon = icon
        self.iconSelected = iconSelected
        self.backgroundColor = backgroundColor
        self.selectedBackgroundColor = selectedBackgroundColor
        self.action = action
    }
    
}

class CallView: UIView {
    var state: CallViewState = CallViewState()
    let mediaState = MediaCallState()
    /// Views
    let rootSheetView = RootSheetView()
    let hiddenButtonsView = CallTableOptionsView()
    let visibleButtonsView = CallControlButtonsView()
    let movingContainerOverlay = FloatingWindowView()
    
    let mediaView = MediaCallView()
    let voiceCallView = VoiceCallView()
    /// Actions
    var onPipTap: (() -> Void)?
    var onTimerRefresh: (() -> (String))?
    var callDurationTimer: Timer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupBottomSheet()
        setupVoiceCallView()
        
        voiceCallView.collapseButton.addTarget(self, action: #selector(pipToggle), for: .touchDown)
        mediaView.header.collapseButton.addTarget(self, action: #selector(pipToggle), for: .touchDown)
        
        updateState(with: state.callState, remoteMuted: state.isRemoteMuted, title: state.title)
        setupFloatingWindow()
        
        hiddenButtonsView.contentDidChange = { [weak self] in
            self?.rootSheetView.refreshOffset()
        }
        
        rootSheetView.stateDidChange = { [weak self] in
            guard let self = self else { return }
            self.movingContainerOverlay.bottomOffset = self.rootSheetView.contentView.frame.height
            - self.rootSheetView.contentViewBottomAnchor.constant
            - self.safeAreaInsets.bottom

            self.movingContainerOverlay.refreshWithCurrentPositionToBounds()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        movingContainerOverlay.bottomOffset = rootSheetView.contentView.frame.height
        - rootSheetView.contentViewBottomAnchor.constant
        - safeAreaInsets.bottom
        
        movingContainerOverlay.refreshWithCurrentPositionToBounds()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupBottomSheet() {
        rootSheetView.contentView.backgroundColor = MMWebRTCSettings.sharedInstance.sheetBackgroundColor
        rootSheetView.layer.zPosition = 999
        // MARK: - Not expanded content
        visibleButtonsView.translatesAutoresizingMaskIntoConstraints = false
        rootSheetView.contentView.mediumContentView.addSubview(visibleButtonsView)
        
        NSLayoutConstraint.activate([
            visibleButtonsView.leadingAnchor.constraint(equalTo: visibleButtonsView.superview!.leadingAnchor),
            visibleButtonsView.trailingAnchor.constraint(equalTo: visibleButtonsView.superview!.trailingAnchor),
            visibleButtonsView.topAnchor.constraint(equalTo: visibleButtonsView.superview!.topAnchor),
            visibleButtonsView.bottomAnchor.constraint(equalTo: visibleButtonsView.superview!.bottomAnchor),
        ])
        // MARK: - Expanded content
        hiddenButtonsView.translatesAutoresizingMaskIntoConstraints = false
        rootSheetView.contentView.largeContentView.addSubview(hiddenButtonsView)
        NSLayoutConstraint.activate([
            hiddenButtonsView.leadingAnchor.constraint(equalTo: hiddenButtonsView.superview!.leadingAnchor),
            hiddenButtonsView.trailingAnchor.constraint(equalTo: hiddenButtonsView.superview!.trailingAnchor),
            hiddenButtonsView.topAnchor.constraint(equalTo: hiddenButtonsView.superview!.topAnchor),
            hiddenButtonsView.bottomAnchor.constraint(equalTo: hiddenButtonsView.superview!.bottomAnchor),
        ])
        // MARK: - Setup sheet
        rootSheetView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootSheetView)
        NSLayoutConstraint.activate([
            rootSheetView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootSheetView.trailingAnchor.constraint(equalTo: trailingAnchor),
            rootSheetView.bottomAnchor.constraint(equalTo: bottomAnchor),
            rootSheetView.topAnchor.constraint(equalTo: topAnchor),
        ])
    }
    
    private func setupMediaView() {
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(mediaView)
        
        NSLayoutConstraint.activate([
            mediaView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mediaView.topAnchor.constraint(equalTo: topAnchor),
            mediaView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mediaView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    private func setupVoiceCallView() {
        voiceCallView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(voiceCallView)
        
        NSLayoutConstraint.activate([
            voiceCallView.leadingAnchor.constraint(equalTo: leadingAnchor),
            voiceCallView.trailingAnchor.constraint(equalTo: trailingAnchor),
            voiceCallView.topAnchor.constraint(equalTo: topAnchor),
            voiceCallView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    private func setupFloatingWindow() {
        movingContainerOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(movingContainerOverlay)
        movingContainerOverlay.layer.zPosition = 998
        
        NSLayoutConstraint.activate([
            movingContainerOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            movingContainerOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            movingContainerOverlay.topAnchor.constraint(equalTo: topAnchor),
            movingContainerOverlay.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ])
    }
    
    func setupButtons(
        mediumContent: [VisibleCallButtonContent],
        largeContent: [HiddenCallButtonContent]
    ) {
        visibleButtonsView.setButtons(content: mediumContent)
        hiddenButtonsView.addCell(with: largeContent)
    }

    func updateState(with state: CallState? = nil, remoteMuted: Bool? = nil, title: String? = nil, updateMedia: MediaTrack? = nil) {
        if let title = title {
            self.state.title = title
            self.voiceCallView.titleLabel.text = title
            self.mediaView.header.nameLabel.text = title
        }
        
        if let updateMedia = updateMedia {
            switch self.state.callState {
            case .mediaCall(let mediaCallState):
                mediaCallState.updateTracks(with: updateMedia)
                mediaView.updateMedia(with: mediaCallState, floatingWindow: movingContainerOverlay, isPIP: PIPKit.isPIP, result: { result in
                    if !result {
                        self.updateState(with: .audioCall)
                    }
                })
            default:
                mediaState.updateTracks(with: updateMedia)
                self.mediaView.updateMedia(with: mediaState, floatingWindow: movingContainerOverlay, isPIP: PIPKit.isPIP, result: { result in
                    if result {
                        self.updateState(with: .mediaCall(mediaState))
                    } else {
                        self.updateState(with: .audioCall)
                    }
                })
            }
        }
        
        if let callState = state {
            self.state.callState = callState
            
            switch callState {
            case .calling:
                if voiceCallView.superview == nil {
                    mediaView.removeFromSuperview()
                    setupVoiceCallView()
                }
            case .audioCall:
                startTimer()
                if voiceCallView.superview == nil {
                    mediaView.removeFromSuperview()
                    setupVoiceCallView()
                }
            case .mediaCall(let model):
                startTimer()
                if mediaView.superview == nil {
                    voiceCallView.removeFromSuperview()
                    setupMediaView()
                }
                mediaView.updateMedia(with: model, floatingWindow: movingContainerOverlay, isPIP: PIPKit.isPIP, result: { result in
                    if !result {
                        updateState(with: .audioCall)
                    }
                })
            }
            
            if PIPKit.isPIP {
                pipToggle()
            }
        }
        
        if let remoteMuted = remoteMuted {
            self.voiceCallView.micIcon.isHidden = !remoteMuted
            self.mediaView.header.micIcon.isHidden = !remoteMuted
        }
    }
    
    func startTimer() {
        if self.callDurationTimer != nil { return }
        
        self.callDurationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
            self?.timerRefresh()
        })
    }
    
    private func timerRefresh() {
        self.voiceCallView.statusLabel.text = self.onTimerRefresh?() ?? ""
        self.mediaView.header.timeLabel.text = self.onTimerRefresh?() ?? ""
    }
    
    // MARK: - PIP Related
    @objc private func pipToggle() {
        onPipTap?()
        
        pipVideoLayout(isPIP: PIPKit.isPIP)
        pipVoiceLayout(isPIP: PIPKit.isPIP)
        pipCallLayout(isPIP: PIPKit.isPIP)
    }
    
    private func pipVideoLayout(isPIP: Bool) {
        movingContainerOverlay.movingContainer.isHidden = isPIP
        mediaView.pipLayout(isPIP: isPIP)
        rootSheetView.isHidden = isPIP && state.callState != .audioCall
    }
    
    private func pipVoiceLayout(isPIP: Bool) {
        let isAudioPIP = isPIP && state.callState == .audioCall
        voiceCallView.pipLayout(isPIP: isPIP)
        rootSheetView.setState(.mediumContent)
        rootSheetView.contentView.backgroundColor = isAudioPIP ? .clear : MMWebRTCSettings.sharedInstance.sheetBackgroundColor
        rootSheetView.contentView.topBarView.isHidden = isAudioPIP
        rootSheetView.contentView.largeContentView.isHidden = isAudioPIP
    }
    
    private func pipCallLayout(isPIP: Bool) {
        mediaView.header.collapseButton.isSelected = isPIP
        voiceCallView.collapseButton.isSelected = isPIP
        movingContainerOverlay.isHidden = isPIP
        
        movingContainerOverlay.setFloatingWindowPosition(
            x: 0,
            y: movingContainerOverlay.frame.height/2 
            - movingContainerOverlay.movingContainer.frame.height/2
            - movingContainerOverlay.bottomOffset,
            isPIP: PIPKit.isPIP
        )
    }
    // MARK: - Hit test
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let superhitTest = super.hitTest(point, with: event)
        
        if let view = rootSheetView.hitTest(point, with: event) {
            return view
        } else if let view = movingContainerOverlay.hitTest(point, with: event) {
            return view
        }
        return superhitTest
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        movingContainerOverlay.recalculatePosition(isPIP: PIPKit.isPIP)
    }

    public func resetMovingContainerCoord() {
        // When coming back to fullscreen, we move the container, if present, to the original position
        movingContainerOverlay.moveFloatingWindow(
            x: movingContainerOverlay.frame.width - movingContainerOverlay.movingContainer.frame.width/2,
            y: movingContainerOverlay.frame.height - movingContainerOverlay.movingContainer.frame.height/2 - safeAreaInsets.bottom/2
        )
    }
}
#endif
