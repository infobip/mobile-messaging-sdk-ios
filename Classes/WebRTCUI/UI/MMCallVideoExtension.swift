//
//  MMCallVideoExtension.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 02/09/2021.
//  Copyright © 2021 Infobip Ltd. All rights reserved.
//
import UIKit
import AVKit
#if WEBRTCUI_ENABLED
import InfobipRTC
private let mmCCFrameGap: CGFloat = 15

extension MMCallController {
    func initLocalVideoView() {
        let localView = InfobipRTCFactory.videoView(
            frame: self.localVideoView?.frame ?? CGRect.zero, 
            contentMode: .scaleAspectFill)
        localView.layer.cornerRadius = 10.0
        localView.clipsToBounds = true
        if let localVideoView = self.localVideoView {
            self.embedView(localView, into: localVideoView)
        }
        self.localView = localView
        setupLocalViewFrame()
        let videoDragger = UIPanGestureRecognizer(target: self, action: #selector(draggingView))
        self.localVideoView?.addGestureRecognizer(videoDragger)
        self.localVideoView?.layer.zPosition = 1
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
            UIDevice.current.isProximityMonitoringEnabled = false
        }
    }
    
    func setupLocalViewFrame() {
        if UIDevice.current.orientation.isLandscape {
            self.localViewFrame = CGRect(
                x: self.view.frame.origin.x + (self.localVideoView.frame.height / 2 + mmCCFrameGap),
                y: self.view.frame.origin.y + (self.localVideoView.frame.width / 2 + mmCCFrameGap),
                width: self.view.frame.height - self.localVideoView.frame.height - (mmCCFrameGap * 2),
                height: self.view.frame.width - self.localVideoView.frame.width - (mmCCFrameGap * 2)
            )
        } else {
            self.localViewFrame = CGRect(
                x: self.view.frame.origin.x + (self.localVideoView.frame.width / 2 + mmCCFrameGap),
                y: self.view.frame.origin.y + (self.localVideoView.frame.height / 2 + mmCCFrameGap),
                width: self.view.frame.width - self.localVideoView.frame.width - (mmCCFrameGap * 2),
                height: self.view.frame.height - self.localVideoView.frame.height - (mmCCFrameGap * 2)
            )
        }
        localVideoView.center = UIApplication.center
    }
    
    func initRemoteVideoViewConference() {
        let remoteViewConference = InfobipRTCFactory.videoView(
            frame: self.remoteVideoViewConference?.frame ?? CGRect.zero, 
            contentMode: .scaleAspectFill)
        remoteViewConference.clipsToBounds = true
        if let remoteVideoView = self.remoteVideoViewConference {
            self.embedView(remoteViewConference, into: remoteVideoView)
        }
        self.remoteViewconference = remoteViewConference
        self.remoteViewFrameConference = CGRect(
            x: self.view.frame.origin.x + (self.remoteVideoViewConference.frame.width / 2 + mmCCFrameGap),
            y: self.view.frame.origin.y + (self.remoteVideoViewConference.frame.height / 2 + mmCCFrameGap),
            width: self.view.frame.width - self.remoteVideoViewConference.frame.width - (mmCCFrameGap * 2),
            height: self.view.frame.height - self.remoteVideoViewConference.frame.height - (mmCCFrameGap * 2)
        )
        
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
            UIDevice.current.isProximityMonitoringEnabled = false
        }
    }
    
    func addTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.numberOfTouchesRequired = 1
        self.view.addGestureRecognizer(tap)
    }
    
    func initRemoteVideoView() {
        let remoteView = InfobipRTCFactory.videoView(frame: self.view.frame, contentMode: .scaleAspectFit)
        self.embedView(remoteView, into: self.view)
        self.view.sendSubviewToBack(remoteView)
        self.remoteView = remoteView
    }
    
    @objc func draggingView(_ sender: UIPanGestureRecognizer) {
        // Not restricting location feels better on UX
        // if self.localViewFrame?.contains(sender.location(in: self.view)) ?? false {
            self.localVideoView.center = sender.location(in: view)
        // }
    }
    
    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        guard !PIPKit.isPIP else {
            onPipTap(self)
            return
        }
        if callStatus == .ESTABLISHED, isVideoStreaming {
            if !videoStatusBottomView.isHidden {
                statusLabelTimer.invalidate()
            } else {
                hideVideoElements(delayed: true)
            }
            callStatusLabel.isHidden = !self.callStatusLabel.isHidden
            counterpartLabel.isHidden = !self.counterpartLabel.isHidden
            videoStatusTopView.isHidden = !self.videoStatusTopView.isHidden
            videoStatusBottomView.isHidden = !self.videoStatusBottomView.isHidden
        }
    }
    
    @objc private func triggerHideVideoElements() {
        DispatchQueue.main.async {
            self.statusLabelTimer.invalidate()
            self.videoStatusTopView.isHidden = true
            self.videoStatusBottomView.isHidden = true
            self.callStatusLabel.isHidden = true
            self.counterpartLabel.isHidden = true
        }
    }
    
    internal func hideVideoElements(delayed: Bool = false) {
        if delayed {
            statusLabelTimer.invalidate()
            statusLabelTimer = Timer.scheduledTimer(
                timeInterval: 3,
                target: self,
                selector: (#selector(self.triggerHideVideoElements)), userInfo: nil, repeats: false)
        } else {
            triggerHideVideoElements()
        }
    }
    
    internal func showVideoElements() {
        DispatchQueue.main.async {
            self.videoStatusTopView.isHidden = false
            self.videoStatusTopView.layer.zPosition = 2
            
            self.videoStatusBottomView.isHidden = false
            self.videoStatusBottomView.layer.zPosition = 2
            
            self.counterpartLabel.isHidden = false
            self.counterpartLabel.layer.zPosition = 3
            
            self.callStatusLabel.isHidden = false
            self.callStatusLabel.layer.zPosition = 2
            
            if self.isVideoCall {
                self.videoStatusBottomView.cameraFlipper.isHidden = !self.hasLocalVideo
                self.videoStatusBottomView.cameraFlipper.layer.zPosition = 3
            }
        }
    }
    
    func onVideoCallEstablished() {
        DispatchQueue.main.async {
            self.speakerphoneOn = true
            if let applicationCall = self.activeApplicationCall {
                applicationCall.speakerphone(true) { _ in  }
            }
            self.showActiveCallViewElements()
            self.videoStatusBottomView.cameraFlipper.isHidden = !self.hasLocalVideo
            self.videoStatusBottomView.screenShare.isHidden = !self.canScreenShare
            self.hideVideoElements(delayed: true)
        }
    }
    
    func onRemoteVideoAdded(_ videoTrack: VideoTrack?) {
        self.groupImage.isHidden = true
        self.remoteVideoViewConference.isHidden = false
        self.initRemoteVideoViewConference()
        if let remoteView = self.remoteViewconference {
            videoTrack!.addRenderer(remoteView)
        }    
    }
    
    func embedView(_ view: UIView, into containerView: UIView) {
        containerView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|",
                                                                    options: [],
                                                                    metrics: nil,
                                                                    views: ["view": view]))
        
        containerView.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[view]|",
                                                                    options: [],
                                                                    metrics: nil,
                                                                    views: ["view": view]))
        containerView.layoutIfNeeded()
    }
    
    func finalizeVideoCallPreview() {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
            UIDevice.current.isProximityMonitoringEnabled = true
            self.remoteView?.removeFromSuperview()
            self.localView?.removeFromSuperview()
            self.remoteViewconference?.removeFromSuperview()
        }
    }
}
#endif
