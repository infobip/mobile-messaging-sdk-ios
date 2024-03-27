//
//  MediaCallView.swift
//  MobileMessaging
//
//  Created by Maksym Svitlovskyi on 24/09/2023.
//

import UIKit
#if WEBRTCUI_ENABLED
import InfobipRTC

class MediaCallView: UIView {
    /// Views
    lazy var backgroundStreamView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = MMWebRTCSettings.sharedInstance.backgroundColor
        return view
    }()
    private lazy var headerStatusBar: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = MMWebRTCSettings.sharedInstance.backgroundColor
        return view
    }()
    lazy var header: MediaCallViewHeader = {
        let view = MediaCallViewHeader()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    /// Dynamic views & constraints
    private var localVideoView: UIView?
    private var remoteVideoView: UIView?
    private var screenshareVideoView: UIView?
        
    var onStopScreenshareTap: (() -> Void)?
    var onRemoteScreenshareTap: (() -> Void)?
    
    lazy var headerHeightConstraint: NSLayoutConstraint = header.heightAnchor.constraint(equalToConstant: 45)
    
    deinit {
        screenshareVideoView?.removeFromSuperview()
        screenshareVideoView = nil
        screenshareOverlay?.removeFromSuperview()
        screenshareOverlay = nil
        remoteVideoView?.removeFromSuperview()
        remoteVideoView = nil
        localVideoView?.removeFromSuperview()
        localVideoView = nil
    }

    override init(frame: CGRect) {
        super.init(frame: frame)        
        backgroundColor = .clear
        
        addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerHeightConstraint
        ])
        addSubview(headerStatusBar)
        NSLayoutConstraint.activate([
            headerStatusBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerStatusBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerStatusBar.topAnchor.constraint(equalTo: topAnchor),
            headerStatusBar.bottomAnchor.constraint(equalTo: header.topAnchor)
        ])

        addSubview(backgroundStreamView)
        NSLayoutConstraint.activate([
            backgroundStreamView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundStreamView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundStreamView.topAnchor.constraint(equalTo: header.bottomAnchor),
            backgroundStreamView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    lazy var localScreenshareView: LocalScreenshareView = {
        let view = LocalScreenshareView()
        view.onStopScreenshareTap = onStopScreenshareTap
        return view
    }()
    // result -> completion handler, which indicates should view move to media view or not
    func updateMedia(with state: MediaCallState, floatingWindow: FloatingWindowView, isPIP: Bool, result: (Bool) -> Void) {
        remoteVideoView?.removeFromSuperview()
        remoteVideoView = nil

        screenshareVideoView?.removeFromSuperview()
        screenshareVideoView = nil
        
        var isBackgroundStreamExist = false
        
        if let anyScreenshare = state.anyScreenshare {
            var videoView = createVideoView(with: .scaleAspectFit)
            switch anyScreenshare {
            case .local(let videoTrack):
                videoTrack.addRenderer(videoView)
                videoView = localScreenshareView
            case .remote(let videoTrack):
                videoTrack.addRenderer(videoView)
                let gesture = UITapGestureRecognizer(target: self, action: #selector(onRemoteScreenshareDidTap))
                videoView.addGestureRecognizer(gesture)
            }
            self.screenshareVideoView = videoView
            setupBackgroundStreamView(with: videoView)
            isBackgroundStreamExist = true
        }
        
        var remoteFloatingWindowView: UIView?
        if let remoteVideo = state.remoteVideo {
            if isBackgroundStreamExist {
                let videoView = createVideoView(with: .scaleAspectFill)
                self.remoteVideoView = videoView
                remoteVideo.addRenderer(videoView)
                remoteFloatingWindowView = remoteVideoView
            } else {
                let videoView = createVideoView(with: .scaleAspectFit)
                self.remoteVideoView = videoView
                remoteVideo.addRenderer(videoView)
                setupBackgroundStreamView(with: videoView)
                isBackgroundStreamExist = true
            }
        }
        
        result(isBackgroundStreamExist)
        
        var localFloatingWindowView: UIView?
        if let localVideo = state.localVideo {
            let videoView = createVideoView(with: .scaleAspectFill)
            localVideo.addRenderer(videoView)
            localFloatingWindowView = videoView
        }
        
        floatingWindow.setup(with: localFloatingWindowView, secondView: remoteFloatingWindowView, isPIP: isPIP)
        
        func createVideoView(with mode: UIView.ContentMode) -> UIView {
            let view = InfobipRTCFactory.videoView(frame: .zero, contentMode: mode)
            return view
        }
    }
    
    func setupBackgroundStreamView(with view: UIView) {
        backgroundStreamView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: backgroundStreamView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: backgroundStreamView.trailingAnchor),
            view.topAnchor.constraint(lessThanOrEqualTo: backgroundStreamView.topAnchor),
            view.bottomAnchor.constraint(greaterThanOrEqualTo: backgroundStreamView.bottomAnchor)
        ])
    }

    var screenshareOverlay: UIView?
    @objc private func onRemoteScreenshareDidTap() {
        onRemoteScreenshareTap?()
    }
    
    func addScreenshareOverlay() {
        if let screenshareVideoView = screenshareVideoView, screenshareOverlay == nil {
            let button = MMCallButton()
            button.set(
                .init(
                    icon: MMWebRTCSettings.sharedInstance.landscapeOnIcon,
                    iconSelected: MMWebRTCSettings.sharedInstance.landscapeOffIcon,
                    backgroundColor: .white.withAlphaComponent(0.15),
                    action: { [weak self] button in
                        self?.changeOrientation()
                        button.isSelected = !button.isSelected
            }))
            
            let overlay = UIView()
            overlay.addSubview(button)
            overlay.backgroundColor = .gray.withAlphaComponent(0.15)
            
            
            screenshareVideoView.addSubview(overlay)
            
            overlay.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: screenshareVideoView.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: screenshareVideoView.trailingAnchor),
                overlay.topAnchor.constraint(equalTo: screenshareVideoView.topAnchor),
                overlay.bottomAnchor.constraint(equalTo: screenshareVideoView.bottomAnchor)
            ])
            
            
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
                button.widthAnchor.constraint(equalToConstant: 50),
                button.heightAnchor.constraint(equalToConstant: 50)
            ])
            
            self.screenshareOverlay = overlay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: {
                UIView.animate(withDuration: 0.5, delay: 0, animations: {
                    self.screenshareOverlay?.layer.opacity = 0
                }, completion: { _ in
                    self.screenshareOverlay?.removeFromSuperview()
                    self.screenshareOverlay = nil
                })
            })
        }
    }
    // MARK: Moving logic
    // MARK: Orientaiton
    private func changeOrientation()  {
        if #available(iOS 16.0, *) {
            if UIApplication.shared.statusBarOrientation.isLandscape {
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            } else {
                let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
            }
        } else {
            if UIDevice.current.orientation.isLandscape {
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            } else {
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            }
        }
    }
    
    func pipLayout(isPIP: Bool) {
        header.headerStack.axis = isPIP ? .vertical : .horizontal
        header.headerStack.alignment = isPIP ? .top : .center
        header.dividerView.isHidden = isPIP
        header.headerStack.spacing = isPIP ? 0 : 8
        headerHeightConstraint.constant = isPIP ? 90 : 45
    }
}
#endif
