//
//  MMWebRTCSettings.swift
//  MobileMessaging
//
//  Created by Mykhailo Kotov on 14/11/2022.
//

import Foundation
import WebKit
#if WEBRTCUI_ENABLED
public class MMWebRTCSettings: NSObject {
    	
    public static let sharedInstance = MMWebRTCSettings()
    
    private var _pulseStrokeColor: UIColor!
    private var _errorColor: UIColor!
    private var _primaryColor: UIColor!
    private var _foregroundColor: UIColor!
    private var _notificationColor: UIColor!
    private var _textSecondaryColor: UIColor!
    private var _backgroundColor: UIColor!
    private var _overlayBackgroundColor: UIColor!
    private var _alertBackgroundColor: UIColor!

    // Color of the pulsating icon border when the ringing call UI is animating
    public var pulseStrokeColor: UIColor! {
        set { _pulseStrokeColor = newValue }
        get { return _pulseStrokeColor ?? UIColor(hexString: "#ffffff") }
    }
    public var errorColor: UIColor! {
        set { _errorColor = newValue }
        get { return _errorColor ?? UIColor(hexString: "#e6ff3b30") }
    }
    public var primaryColor: UIColor! {
        set { _primaryColor = newValue }
        get { return _primaryColor ?? UIColor(hexString: "#29B899") }
    }
    /// Color of text and elements on foreground
    public var foregroundColor: UIColor! {
        set { _foregroundColor = newValue }
        get { return _foregroundColor ?? pulseStrokeColor }
    }
    /// Color of less prominent texts
    public var textSecondaryColor: UIColor! {
        set { _textSecondaryColor = newValue }
        get { return _textSecondaryColor ?? UIColor(hexString: "#7AFFFFFF") }
    }
    /// Background color of calls
    public var backgroundColor: UIColor! {
        set { _backgroundColor = newValue }
        get { return _backgroundColor ?? UIColor(hexString: "#242424") }
    }
    /// Background color of toolbar in video call
    public var overlayBackgroundColor: UIColor! {
        set { _overlayBackgroundColor = newValue }
        get { return _overlayBackgroundColor ?? UIColor(hexString: "#80242424") }
    }
    public var alertBackgroundColor: UIColor! {
        set { _alertBackgroundColor = newValue }
        get { return _alertBackgroundColor ?? UIColor(hexString: "#99050708") }
    }

    private var _iconMute: UIImage?
    private var _iconUnMute: UIImage?
    private var _iconMutedParticipant: UIImage?
    private var _iconScreenShareOn: UIImage?
    private var _iconScreenShareOff: UIImage?
    private var _iconAvatar: UIImage?
    private var _iconVideo: UIImage?
    private var _iconVideoOff: UIImage?
    private var _iconSpeaker: UIImage?
    private var _iconSpeakerOff: UIImage?
    private var _iconFlipCamera: UIImage?
    private var _iconEndCall: UIImage?
    private var _iconExpand: UIImage?
    private var _iconCollapse: UIImage?
    private var _iconCounterpart: UIImage?
    private var _iconDialpad: UIImage?
    private var _iconAlert: UIImage?
    private var _soundStartCall: NSDataAsset?
    private var _soundEndCall: NSDataAsset?

    public var iconMute: UIImage? {
        set { _iconMute = newValue }
        get { return _iconMute ?? UIImage.init(mm_webrtcui_named: "mic") }
    }
    public var iconUnMute: UIImage? {
        set { _iconUnMute = newValue }
        get { return _iconUnMute ?? UIImage.init(mm_webrtcui_named: "micoff") }
    }
    public var iconMutedParticipant: UIImage? {
        set { _iconMutedParticipant = newValue }
        get { return _iconMutedParticipant ?? UIImage.init(mm_webrtcui_named: "mutedParticipant") }
    }
    public var iconScreenShareOn: UIImage? {
        set { _iconScreenShareOn = newValue }
        get { return _iconScreenShareOn ?? UIImage.init(mm_webrtcui_named: "shareScreenOn") }
    }
    public var iconScreenShareOff: UIImage? {
        set { _iconScreenShareOff = newValue }
        get { return _iconScreenShareOff ?? UIImage.init(mm_webrtcui_named: "shareScreenOff") }
    }
    public var iconAvatar: UIImage? {
        set { _iconAvatar = newValue }
        get { return _iconAvatar ?? UIImage.init(mm_webrtcui_named: "icon-user-s-grayscale") }
    }
    public var iconVideo: UIImage? {
        set { _iconVideo = newValue }
        get { return _iconVideo ?? UIImage.init(mm_webrtcui_named: "video") }
    }
    public var iconVideoOff: UIImage? {
        set { _iconVideoOff = newValue }
        get { return _iconVideoOff ?? UIImage.init(mm_webrtcui_named: "videooff") }
    }
    public var iconSpeaker: UIImage? {
        set { _iconSpeaker = newValue }
        get { return _iconSpeaker ?? UIImage.init(mm_webrtcui_named: "speaker") }
    }
    public var iconSpeakerOff: UIImage? {
        set { _iconSpeakerOff = newValue }
        get { return _iconSpeakerOff ?? UIImage.init(mm_webrtcui_named: "speakeroff") }
    }
    public var iconFlipCamera: UIImage? {
        set { _iconFlipCamera = newValue }
        get { return _iconFlipCamera ?? UIImage.init(mm_webrtcui_named: "flipCamera") }
    }
    public var iconEndCall: UIImage? {
        set { _iconEndCall = newValue }
        get { return _iconEndCall ?? UIImage.init(mm_webrtcui_named: "hangup") }
    }
    public var iconExpand: UIImage? {
        set { _iconExpand = newValue }
        get { return _iconExpand ?? UIImage.init(mm_webrtcui_named: "expandIcon") }
    }
    public var iconCollapse: UIImage? {
        set { _iconCollapse = newValue }
        get { return _iconCollapse ?? UIImage.init(mm_webrtcui_named: "collapseIcon") }
    }
    public var iconCounterpart: UIImage? {
        set { _iconCounterpart = newValue }
        get { return _iconCounterpart ?? UIImage.init(mm_webrtcui_named: "counterpart") }
    }
    public var iconDialpad: UIImage? {
        set { _iconDialpad = newValue }
        get { return _iconDialpad ?? UIImage.init(mm_webrtcui_named: "dialpad") }
    }
    public var iconAlert: UIImage? {
        set { _iconAlert = newValue }
        get { return _iconAlert ?? UIImage.init(mm_webrtcui_named: "alertBarIcon") }
    }
    public var soundStartCall: NSDataAsset! {
        set { _soundStartCall = newValue }
        get {
            guard let dataAsset = _soundStartCall else {
                return NSDataAsset(mm_webrtcui_named: "MMOutboundCall")
            }
            return dataAsset
        }
    }
    public var soundEndCall: NSDataAsset! {
        set { _soundEndCall = newValue }
        get {
            guard let dataAsset = _soundEndCall else {
                return NSDataAsset(mm_webrtcui_named: "MMDisconnectedCall")
            }
            return dataAsset
        }
    }
    public var inboundCallSoundFileName: String?

    struct Keys {
        static let pulseStrokeColor = "rtc_ui_pulse_stroke"
        static let errorColor = "rtc_ui_error"
        static let primaryColor = "rtc_ui_primary"
        static let foregroundColor = "rtc_ui_color_foreground"
        static let textSecondaryColor = "rtc_ui_color_text_secondary"
        static let backgroundColor = "rtc_ui_color_background"
        static let overlayBackgroundColor = "rtc_ui_color_overlay_background"
        static let alertBackgroundColor = "rtc_ui_color_alert_background"
    }

    public func configureWith(rawConfig: [String: String]) {
        if let pulseStrokeColor = rawConfig[MMWebRTCSettings.Keys.pulseStrokeColor] {
            self.pulseStrokeColor = UIColor(hexString: pulseStrokeColor)
        }
        if let errorColor = rawConfig[MMWebRTCSettings.Keys.errorColor] {
            self.errorColor = UIColor(hexString: errorColor)
        }
        if let primaryColor = rawConfig[MMWebRTCSettings.Keys.primaryColor] {
            self.primaryColor = UIColor(hexString: primaryColor)
        }
        if let foregroundColor = rawConfig[MMWebRTCSettings.Keys.foregroundColor] {
            self.foregroundColor = UIColor(hexString: foregroundColor)
        }
        if let textSecondaryColor = rawConfig[MMWebRTCSettings.Keys.textSecondaryColor] {
            self.textSecondaryColor = UIColor(hexString: textSecondaryColor)
        }
        if let backgroundColor = rawConfig[MMWebRTCSettings.Keys.backgroundColor] {
            self.backgroundColor = UIColor(hexString: backgroundColor)
        }
        if let overlayBackgroundColor = rawConfig[MMWebRTCSettings.Keys.overlayBackgroundColor] {
            self.overlayBackgroundColor = UIColor(hexString: overlayBackgroundColor)
        }
        if let alertBackgroundColor = rawConfig[MMWebRTCSettings.Keys.alertBackgroundColor] {
            self.alertBackgroundColor = UIColor(hexString: alertBackgroundColor)
        }
    }
}
#endif
