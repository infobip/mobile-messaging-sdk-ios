//
//  MMCallPopoverExtension.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 19/08/2021.
//  Copyright © 2021 Infobip Ltd. All rights reserved.
//
#if WEBRTCUI_ENABLED
extension MMCallController {
    func hideCallRelatedViewElements() {
        self.videoStatusBottomView.update(top: [], bottom: [])
    }
    
    func showOutgoingCallViewElements() {
        self.videoStatusBottomView.isHidden = false
        self.videoStatusBottomView.update(top: [], bottom: [.hangup])
        self.pulse.isHidden = false
    }
    
    func showActiveCallViewElements() {
        guard !PIPKit.isPIP else { return }
        if hasRemoteVideo {
            self.pulse.isHidden = true
        } else {
            self.pulse.isHidden = false
        }
        self.stopPulse()
        if callType == .pstn {
            self.videoStatusBottomView.update(top: [.mute, .blank, .speaker],
                                              bottom: [canShowDialpad ? .dialpad :.blank, .hangup,
                                                       canScreenShare ? .screenShare : .blank])

        } else {
            self.videoStatusBottomView.update(top: [.mute, .localVideo, .speaker],
                                              bottom: [ hasLocalVideo ? .cameraFlipper : .blank,
                                                            .hangup, canScreenShare ? .screenShare : .blank])
            self.videoStatusBottomView.localVideo.isSelected = hasLocalVideo
        }
        self.videoStatusBottomView.isHidden = false
        self.callStatusLabel.isHidden = false
        self.counterpartLabel.isHidden = false
    }
}
#endif
