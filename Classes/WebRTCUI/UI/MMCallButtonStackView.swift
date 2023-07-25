//
//  MMCallButtonStackView.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 19/08/2021.
//  Copyright © 2021 Infobip Ltd. All rights reserved.
//

import UIKit
import Foundation

#if WEBRTCUI_ENABLED
enum CallButtonType {
    case mute,
         speaker,
         localVideo,
         screenShare,
         hangup,
         cameraFlipper,
         dialpad,
         blank
}

class CallButton: UIButton {
    let buttonGap: CGFloat = 5
    @IBOutlet weak var xConstraint: NSLayoutConstraint!
    @IBOutlet weak var yConstraint: NSLayoutConstraint!

    override func titleRect(forContentRect contentRect: CGRect) -> CGRect {
        let rect = super.titleRect(forContentRect: contentRect)

        return CGRect(x: 0, y: contentRect.height - rect.height + buttonGap,
            width: contentRect.width, height: rect.height + buttonGap)
    }

    override func imageRect(forContentRect contentRect: CGRect) -> CGRect {
        let rect = super.imageRect(forContentRect: contentRect)
        let titleRect = self.titleRect(forContentRect: contentRect)

        return CGRect(x: contentRect.width/2.0 - rect.width/2.0,
            y: (contentRect.height - titleRect.height)/2.0 - rect.height/2.0,
            width: rect.width, height: rect.height)
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        if let image = imageView?.image {
            var labelHeight: CGFloat = 0.0
            if let size = titleLabel?.sizeThatFits(CGSize(width: self.contentRect(forBounds: self.bounds).width,
                                                          height: CGFloat.greatestFiniteMagnitude)) {
                labelHeight = size.height
            }
            return CGSize(width: size.width, height: image.size.height + labelHeight + buttonGap)
        }
        return size
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        centerTitleLabel()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        centerTitleLabel()
    }

    private func centerTitleLabel() {
        self.titleLabel?.textAlignment = .center
        self.titleLabel?.lineBreakMode = .byTruncatingMiddle
        self.titleLabel?.minimumScaleFactor = 0.5
        self.titleLabel?.numberOfLines = 2
        self.titleLabel?.font = UIFont.systemFont(ofSize: 14)
    }
}
class CallButtonStackView: UIView {
    func applySettings() {
        let settings = MMWebRTCSettings.sharedInstance
        hangup.setImage(settings.iconEndCall, for: .normal)
        mute.setTitle(MMLoc.microphone.lowercased(), for: .normal)
        mute.setImage(settings.iconMute, for: .normal)
        mute.setImage(settings.iconUnMute, for: .selected)
        localVideo.setTitle(MMLoc.videoCall.lowercased(), for: .normal)
        localVideo.setImage(settings.iconVideo, for: .selected)
        localVideo.setImage(settings.iconVideoOff, for: .normal)
        speaker.setTitle(MMLoc.speaker.lowercased(), for: .normal)
        speaker.setImage(settings.iconSpeaker, for: .normal)
        speaker.setImage(settings.iconSpeakerOff, for: .selected)
        cameraFlipper.setTitle(MMLoc.flipCamera.lowercased(), for: .normal)
        cameraFlipper.setImage(settings.iconFlipCamera, for: .normal)
        screenShare.setTitle(MMLoc.screenShare.lowercased(), for: .normal)
        screenShare.setImage(settings.iconScreenShareOn, for: .normal)
        screenShare.setImage(settings.iconScreenShareOff, for: .selected)
        dialpad.setTitle(MMLoc.dialpad.lowercased(), for: .normal)
        dialpad.setImage(settings.iconDialpad, for: .normal)
        self.backgroundColor = .clear
    }

    @IBOutlet weak var mute: CallButton!
    @IBOutlet weak var speaker: CallButton!
    @IBOutlet weak var localVideo: CallButton!
    @IBOutlet weak var screenShare: CallButton!
    @IBOutlet weak var hangup: CallButton!
    @IBOutlet weak var cameraFlipper: CallButton!
    @IBOutlet weak var placeholder: CallButton!
    @IBOutlet weak var dialpad: CallButton!

    func setupButtons() {
        applySettings()
        placeholder.isHidden = true
    }

    func button(_ callButtonType: CallButtonType) -> CallButton? {
        switch callButtonType {
        case .mute:
            return mute
        case .speaker:
            return speaker
        case .localVideo:
            return localVideo
        case .screenShare:
            return screenShare
        case .hangup:
            return hangup
        case .cameraFlipper:
            return cameraFlipper
        case .dialpad:
            return dialpad
        default:
            return nil
        }
    }

    func update(top: [CallButtonType],
                bottom: [CallButtonType]) {
        hideElements()
        let linesCount = (top.isEmpty ? 0 : 1) + (bottom.isEmpty ? 0 : 1)
        [top, bottom].enumerated().forEach { (row, callButtons) in
            let buttonsCount = callButtons.count
            let notEmptyRow = top.isEmpty ? 0 : row
            callButtons.enumerated().forEach { (index, callButtonType) in
                let button = self.button(callButtonType)
                button?.isHidden = false
                button?.xConstraint = button?
                    .xConstraint
                    .set(multiplier: 2.0 * CGFloat(index + 1) / CGFloat(buttonsCount + 1))
                button?.yConstraint = button?
                    .yConstraint
                    .set(multiplier: 2.0 * (CGFloat(notEmptyRow) * 2 + 1) / CGFloat(linesCount * 2))
            }
        }
    }

    private func hideElements() {
        self.hangup.isHidden = true
        self.mute.isHidden = true
        self.speaker.isHidden = true
        self.localVideo.isHidden = true
        self.screenShare.isHidden = true
        self.cameraFlipper.isHidden = true
        self.placeholder.isHidden = true
        self.dialpad.isHidden = true
    }
}

extension NSLayoutConstraint {
    func set(multiplier: CGFloat) -> NSLayoutConstraint {
        guard let firstItem = firstItem else {
            return self
        }
        NSLayoutConstraint.deactivate([self])
        let newConstraint = NSLayoutConstraint(item: firstItem,
                                               attribute: firstAttribute,
                                               relatedBy: relation,
                                               toItem: secondItem,
                                               attribute: secondAttribute,
                                               multiplier: multiplier,
                                               constant: constant)
        newConstraint.priority = priority
        newConstraint.shouldBeArchived = self.shouldBeArchived
        newConstraint.identifier = self.identifier
        NSLayoutConstraint.activate([newConstraint])
        return newConstraint
    }
}
#endif
