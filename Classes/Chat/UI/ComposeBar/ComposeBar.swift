// 
//  ComposeBar.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UIKit

fileprivate typealias consts = ComposeBarConsts

struct ComposeBarConsts {
	// runtime consts
	static var kTextViewLineHeight: CGFloat = 0.0
	static var kTextViewFirstLineHeight: CGFloat = 0.0
	static var kTextViewToSuperviewHeightDelta: CGFloat = 0.0
	
	static let kResizeAnimationCurve 		            = UIView.AnimationCurve.easeInOut
	static let kResizeAnimationOptions 		            = UIView.AnimationOptions.curveEaseInOut
	static let kResizeAnimationDuration: CGFloat 	    = 0.25
	static let kHorizontalSpacing: CGFloat          	= 4.0
	static let kFontSize: CGFloat                   	= 16.0
	static let kTextContainerTopMargin: CGFloat     	= 8.0
	static let kTextContainerBottomMargin: CGFloat  	= 8.0
	static let kTextContainerLeftPadding: CGFloat   	= 3.0
	static let kTextContainerRightPadding: CGFloat  	= 2.0
	static let kTextContainerTopPadding: CGFloat    	= 8.0
	static let kTextContainerCornerRadius: CGFloat  	= 0.0
	static let kTextViewTopMargin: CGFloat          	= -8.0
	static let kPlaceholderHeight: CGFloat          	= 25.0
	static let kPlaceholderSideMargin: CGFloat      	= 8.0
	static let kPlaceholderTopMargin: CGFloat       	= 4.0
	static let kButtonHeight: CGFloat               	= 32.0
	static let kButtonTouchableOverlap: CGFloat     	= 6.0
	static let kButtonRightMargin: CGFloat          	= 8.0
	static let kButtonBottomMargin: CGFloat         	= 8.0
	static let kUtilityButtonWidth: CGFloat         	= 32.0
	static let kUtilityButtonHeight: CGFloat        	= 32.0
	static let kUtilityButtonBottomMargin: CGFloat  	= 6.0
	static let kCaretYOffset: CGFloat               	= 7.0
	static let kCharCounterFontSize: CGFloat          	= 11.0
	static let kInitialHeight: CGFloat 				    = 44.0
    static let kMainTextColor: UIColor                  = .black
    static let kMainPlaceholderTextColor: UIColor       = UIColor(hue: 240/360, saturation: 0.02, brightness: 0.8, alpha: 1.0)
    static let kTextInputBackgroundColor: UIColor       = .clear
    static let kTypingIndicatorColor: UIColor           = .black
    static let kSendButtonIcon: UIImage?                = UIImage(mm_chat_named: "sendButton")
    static let kAttachmentButtonIcon: UIImage?          = UIImage(mm_chat_named: "attachmentButton")
    static let kIsLineSeparatorHidden: Bool             = false
    static let kMainFont: UIFont                        = UIFont.systemFont(ofSize: consts.kFontSize)
    
    static let kCharCounterTrailing                     = 140.0
    static let kCharCounterTop                          = 14.0
    static let kCharCounterWidth                        = 100.0
    static let kCharCounterHeight                       = 15.0
    static let kCharCounterFont: UIFont                 = UIFont.systemFont(ofSize: consts.kCharCounterFontSize)
    static let kCharCounterDefaultColor: UIColor        = .lightGray
    static let kCharCounterAlertColor: UIColor          = .red
	
	struct Notifications {
		static let didChangeFrameNotification           = "ComposeBarDidChangeFrameNotification"
		static let willChangeFrameNotification          = "ComposeBarWillChangeFrameNotification"
		
		struct Keys {
			static let animationDurationUserInfoKey     = "ComposeAnimationDurationUserInfoKey"
			static let animationCurveUserInfoKey        = "ComposeAnimationCurveUserInfoKey"
			static let frameBeginUserInfoKey            = "ComposeBarFrameBeginUserInfoKey"
			static let frameEndUserInfoKey              = "ComposeBarFrameEndUserInfoKey"
		}
	}
}

class ComposeBar: UIView, MMChatComposer, UITextViewDelegate {
    public var settings = MMChatSettings.settings.advancedSettings

    lazy var sendButton: ComposeBar_Send_Button! = {
        let ret = ComposeBar_Send_Button()
        ret.frame = CGRect(
            x: self.bounds.size.width - consts.kHorizontalSpacing - settings.buttonRightMargin - settings.buttonTouchableOverlap,
            y: self.bounds.size.height - settings.buttonBottomMargin - settings.buttonHeight,
            width: 2 * settings.buttonTouchableOverlap,
            height: settings.buttonHeight
        )
        ret.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
        ret.addTarget(self, action: #selector(ComposeBar.didPressSendButton), for: .touchUpInside)
        return ret
    }()
    
	public var autoAdjustTopOffset: Bool = true {
		didSet {
			autoresizingMask = {
				if autoAdjustTopOffset == true {
					return autoresizingMask.union(.flexibleTopMargin)
				} else {
					return autoresizingMask.symmetricDifference(.flexibleTopMargin)
				}
			}()
		}
	}
    
	public var sendButtonTintColor: UIColor? {
		get {
			return sendButton.enabledTintColor
		}
		set {
			sendButton.enabledTintColor = newValue
		}
	}
    
    public var utilityButtonTintColor: UIColor? {
        get {
            return utilityButton.enabledTintColor
        }
        set {
            utilityButton.enabledTintColor = newValue
        }
    }
	
    public weak var delegate: MMComposeBarDelegate?
	public var isEnabled: Bool = true {
		didSet {
			textView.isEditable = isEnabled
			updateSendButtonEnabled()
			utilityButton?.isEnabled = isEnabled
		}
	}
	public var maxHeight: CGFloat = 0 {
		didSet {
			resizeTextViewIfNeededAnimated(true)
			scrollToCaretIfNeeded()
		}
	}
	public var maxLinesCount: CGFloat {
		get {
			let maxTextHeight = maxHeight - settings.initialHeight + consts.kTextViewLineHeight
			return maxTextHeight / consts.kTextViewLineHeight
		}
		set {
			let maxTextHeight = newValue * consts.kTextViewLineHeight
			let maxHeight = maxTextHeight - consts.kTextViewLineHeight + settings.initialHeight
			self.maxHeight = maxHeight
		}
	}
	public var placeholder: String? {
		get {
			return placeholderLabel.text
		}
		set {
			placeholderLabel.text = newValue
		}
	}
	lazy var placeholderLabel: UILabel! = {
		let ret = UILabel(frame: CGRect.zero)
		ret.backgroundColor = UIColor.clear
		ret.isUserInteractionEnabled = false
		ret.autoresizingMask = .flexibleWidth
		ret.adjustsFontSizeToFitWidth = true
		ret.minimumScaleFactor = UIFont.smallSystemFontSize / consts.kFontSize
		return ret
	}()
    
	public var text: String {
		get {
			return textView.text
		}
		set {
			setText(newValue, animated: true)
		}
	}
    
	lazy var textView: ComposeBar_TextView! = {
		let ret = ComposeBar_TextView(frame: CGRect.zero)
		ret.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		ret.scrollIndicatorInsets = UIEdgeInsets(top: 8.0, left: 0, bottom: 8.0, right: 0.5)
		return ret
	}()
    
	lazy var utilityButton: ComposeBar_Button! = {
		let ret = ComposeBar_Button(type: .custom)
		ret.autoresizingMask = [.flexibleRightMargin, .flexibleTopMargin]
		ret.frame = CGRect(
            x: 0,
            y: self.bounds.size.height - settings.utilityButtonHeight - settings.utilityButtonBottomMargin,
            width: settings.utilityButtonWidth,
            height: settings.utilityButtonHeight
        )
		ret.addTarget(self, action: #selector(ComposeBar.didPressUtilityButton), for: .touchUpInside)
		return ret
	}()
    
	public var utilityButtonImage: UIImage? {
		get {
			return utilityButton.image(for: .normal)
		}
		set {
			utilityButton.setImage(newValue, for: .normal)
			updateUtilityButtonVisibility()
		}
	}
    
    public var isAttachmentUploadEnabled: Bool = false {
        didSet {
            updateUtilityButtonVisibility()
        }
    }

	//MARK: - Public methods
	
	public func setText(_ txt: String, animated: Bool) {
		textView.text = txt
		handleTextViewChangeAnimated(animated)
	}
	
	lazy var backgroundView: UIToolbar! = {
		var frame = self.bounds
		frame.origin.y = 0.5
		let ret = UIToolbar(frame: frame)
		ret.barStyle = .default
		ret.isTranslucent = false
		ret.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		return ret
	}()
    
	lazy var charCounterLabel: UILabel! = {
        let ret = UILabel(frame: CGRect(
            x: self.bounds.size.width - consts.kCharCounterTrailing,
            y: self.bounds.size.height - consts.kCharCounterTop,
            width: consts.kCharCounterWidth,
            height: consts.kCharCounterHeight)
        )
    	ret.isHidden = true // will be updated dynamically
		ret.textAlignment = .right
        ret.textColor = settings.charCounterDefaultColor
		ret.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
		ret.font = settings.charCounterFont
		return ret
	}()

	lazy var textContainer: UIButton! = {
        let textContainerFrame = CGRect(
            x: consts.kHorizontalSpacing,
            y: settings.textContainerTopMargin,
            width: self.bounds.size.width - consts.kHorizontalSpacing * 3 - settings.buttonRightMargin,
            height: self.bounds.size.height - settings.textContainerTopMargin - settings.textContainerBottomMargin
        )
		let ret = UIButton(type: .custom)
		ret.frame = textContainerFrame
		ret.clipsToBounds = true
		ret.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		let txtH = self.textHeight
		self.previousTextHeight = txtH
		var textViewFrame = textContainerFrame
		textViewFrame.origin.x = settings.textContainerLeftPadding
		textViewFrame.origin.y = settings.textContainerTopPadding + settings.textViewTopMargin
		textViewFrame.size.width = textViewFrame.size.width - settings.textContainerLeftPadding - settings.textContainerRightPadding
		textViewFrame.size.height = self.textHeight
		self.textView.frame = textViewFrame
		ret.addSubview(self.textView)
		
		let placeholderFrame = CGRect(
            x: settings.placeholderSideMargin,
            y: settings.placeholderTopMargin,
            width: textContainerFrame.size.width - 2 * settings.placeholderSideMargin,
            height: settings.placeholderHeight
        )
		
		self.placeholderLabel.frame = placeholderFrame
		ret.addSubview(self.placeholderLabel)
		ret.addTarget(self.textView, action: #selector(UITextView.becomeFirstResponder), for: .touchUpInside)
		return ret
	}()
	
	lazy var previousTextHeight: CGFloat = {
		return self.bounds.size.height
	}()
	
	//MARK: - UIView Overridings

	override init(frame: CGRect) {
		super.init(frame: frame)
		calculateRuntimeConstants()
		setup()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
    
    init(frame: CGRect, settings: MMAdvancedChatSettings) {
        super.init(frame: frame)
        self.settings = settings
        calculateRuntimeConstants()
        setup()
    }
	
	override func awakeFromNib() {
		super.awakeFromNib()
		calculateRuntimeConstants()
		setup()
	}
	
	override func becomeFirstResponder() -> Bool {
		return textView.becomeFirstResponder()
	}
	
	override var canBecomeFirstResponder: Bool {
		get {
			return textView.canBecomeFirstResponder
		}
	}
	
	override var isFirstResponder: Bool {
		get {
			return textView.isFirstResponder
		}
	}
	
	@discardableResult
	override func resignFirstResponder() -> Bool {
		return textView.resignFirstResponder()
	}
	
	override func didMoveToSuperview() {
		updateSendButtonEnabled()
		resizeTextViewIfNeededAnimated(false)
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()

		// Correct background view position:
		backgroundView.frame = {
			var ret = backgroundView.frame
			ret.size.height = self.bounds.size.height
			ret.origin.y = 0.5
			return ret
		}()

		updateCharCounterLabel()
		resizeTextViewIfNeededAnimated(false)
        
        if MMLanguage.sessionLanguage.isRightToLeft { adjustLayoutForRTL() }
	}

	func adjustLayoutForRTL() {
        // This method entirely flips the frames in case right to left language was set, ignoring OS values
        semanticContentAttribute = .forceRightToLeft
		var sendButtonFrame = sendButton.frame
		sendButtonFrame.origin.x = consts.kHorizontalSpacing
		sendButton.frame = sendButtonFrame
		sendButton.autoresizingMask = [.flexibleRightMargin, .flexibleTopMargin]
        sendButton.mmFlipHorizontally()

		if utilityButton.superview != nil {
			var utilityButtonFrame = utilityButton.frame
			utilityButtonFrame.origin.x = self.bounds.size.width - settings.utilityButtonWidth - consts.kHorizontalSpacing
			utilityButton.frame = utilityButtonFrame
			utilityButton.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
            utilityButton.mmFlipHorizontally()
		}

		var textContainerFrame = textContainer.frame
		let leftMargin: CGFloat = utilityButton.superview != nil ?
			(settings.utilityButtonWidth + consts.kHorizontalSpacing * 2) :
			(sendButton.bounds.size.width + consts.kHorizontalSpacing * 2)
		let rightMargin = sendButton.bounds.size.width + consts.kHorizontalSpacing * 2 + settings.buttonRightMargin

		textContainerFrame.origin.x = leftMargin
		textContainerFrame.size.width = self.bounds.size.width - leftMargin - rightMargin
		textContainer.frame = textContainerFrame

		placeholderLabel.textAlignment = .right

		var charCounterFrame = charCounterLabel.frame
		charCounterFrame.origin.x = consts.kHorizontalSpacing
		charCounterLabel.frame = charCounterFrame
		charCounterLabel.textAlignment = .left
		charCounterLabel.autoresizingMask = [.flexibleRightMargin, .flexibleTopMargin]
	}
	
	//MARK: - UITextViewDelegate
	
	func textViewDidChange(_ textView: UITextView) {
		handleTextViewChangeAnimated(false)
        delegate?.textDidChange(text, completion: { _ in })
	}
		
	private func calculateRuntimeConstants() {
		if (consts.kTextViewFirstLineHeight == 0 && consts.kTextViewLineHeight == 0 && consts.kTextViewToSuperviewHeightDelta == 0) {
            consts.kTextViewFirstLineHeight = textHeight
			textView.text = "\n"
            consts.kTextViewLineHeight = textHeight - consts.kTextViewFirstLineHeight
			textView.text = ""
            consts.kTextViewToSuperviewHeightDelta = CGFloat(ceilf(Float(settings.initialHeight) - Float(consts.kTextViewFirstLineHeight)))
		}
	}
	
	private func setup() {
		autoAdjustTopOffset = true
		isEnabled = true
		maxHeight = 200.0
		autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
		addSubview(backgroundView)
		addSubview(charCounterLabel)
		addSubview(sendButton)
		addSubview(textContainer)
        textView.delegate = self
		resizeSendButton()
	}
	
	private func updateSendButtonEnabled() {
		let enabled = isEnabled && textView.text.count > 0 && textView.text.count <= ChatAttachmentUtils.DefaultMaxTextLength
        sendButton.isEnabled = enabled
	}
	
	private func resizeTextViewIfNeededAnimated(_ animated: Bool) {
		guard self.superview != nil else {
			return
		}
		
		let th = textHeight
		let mh = maxHeight

		let pth = previousTextHeight
		let delta = th - pth
		
		guard !(delta == 0 && bounds.size.height == mh) else {
			return
		}
		
		previousTextHeight = th
		let newvh = max(
			min(th + consts.kTextViewToSuperviewHeightDelta, mh),
			settings.initialHeight
		)

		let viewHeightDelta = newvh - bounds.size.height

		guard viewHeightDelta != 0 else {
			return
		}
		
		let animationDurationFactor: CGFloat = animated ? 1.0 : 0.0
		let frameBegin = self.frame
		var frameEnd = frameBegin
		frameEnd.size.height += viewHeightDelta
		
		if autoAdjustTopOffset {
			frameEnd.origin.y = frameEnd.origin.y - viewHeightDelta
		}
                
		let animation = {
			self.frame = frameEnd
		}
		
		let animationDuration = consts.kResizeAnimationDuration * animationDurationFactor
		
		let willChangeUserInfo: [String: Any] = [
			consts.Notifications.Keys.frameBeginUserInfoKey: NSValue.init(cgRect: frameBegin),
			consts.Notifications.Keys.frameEndUserInfoKey: NSValue.init(cgRect: frameEnd),
			consts.Notifications.Keys.animationDurationUserInfoKey: animationDuration,
			consts.Notifications.Keys.animationCurveUserInfoKey: consts.kResizeAnimationCurve
		]
		
		let didChangeUserInfo: [String: Any] = [
			consts.Notifications.Keys.frameBeginUserInfoKey: NSValue.init(cgRect: frameBegin),
			consts.Notifications.Keys.frameEndUserInfoKey: NSValue.init(cgRect: frameEnd)
		]
		
		let afterAnimation: (Bool) -> Void = {[weak self] _ in
			self?.postNotification(name: consts.Notifications.didChangeFrameNotification, userInfo: didChangeUserInfo)
            self?.delegate?.composeBarDidChangeFrom(frameBegin, to: frameEnd)
		}
		
		postNotification(name: consts.Notifications.willChangeFrameNotification, userInfo: willChangeUserInfo)
        delegate?.composeBarWillChangeFrom(frameBegin, to: frameEnd, duration: TimeInterval(animationDuration), animationCurve: consts.kResizeAnimationCurve)
		
		if animated {
			UIView.animate(
                withDuration: TimeInterval(consts.kResizeAnimationDuration * animationDurationFactor),
                delay: 0,
                options: consts.kResizeAnimationOptions,
                animations: animation,
                completion: afterAnimation
            )
		} else {
			animation()
			afterAnimation(true)
		}
	}
	
	private func updateCharCounterLabel() {
        DispatchQueue.mmEnsureMain {
            let count = self.textView.text.count
            let isHidden = count < ChatAttachmentUtils.charCounterVisibleForLength
            self.charCounterLabel.isHidden = isHidden
            if !isHidden {
                self.charCounterLabel.text = "\(count)/\(ChatAttachmentUtils.DefaultMaxTextLength)"
                let exceedsMaxCharLimit = count > ChatAttachmentUtils.DefaultMaxTextLength
                self.charCounterLabel.textColor = exceedsMaxCharLimit ?
                                                self.settings.charCounterAlertColor :
                                                self.settings.charCounterDefaultColor
            }
        }
	}
	
	private func handleTextViewChangeAnimated(_ animated: Bool) {
		updatePlaceholderVisibility()
		resizeTextViewIfNeededAnimated(animated)
		scrollToCaretIfNeeded()
		updateCharCounterLabel()
		updateSendButtonEnabled()
	}
	
	private func resizeSendButton() {
		let previousButtonFrame = sendButton.frame
		var newButtonFrame = previousButtonFrame
		var textContainerFrame = textContainer.frame

        sendButton.sizeToFit()

		let widthDelta = sendButton.bounds.size.width + 2 * settings.buttonTouchableOverlap - previousButtonFrame.size.width

		newButtonFrame.size.width = newButtonFrame.size.width + widthDelta
		newButtonFrame.origin.x = newButtonFrame.origin.x - widthDelta
        sendButton.frame = newButtonFrame

		textContainerFrame.size.width = textContainerFrame.size.width - widthDelta
		textContainer.frame = textContainerFrame
	}
		
	private func scrollToCaretIfNeeded() {
		guard superview != nil, let selectedTextRange = textView.selectedTextRange, !selectedTextRange.isEmpty else
		{
			return
		}
		
		let position = selectedTextRange.start
		var offset = textView.contentOffset
		let relativeCaretY: CGFloat = textView.caretRect(for: position).origin.y - offset.y - consts.kCaretYOffset
		var offsetYDelta: CGFloat = 0.0
		if relativeCaretY < 0.0 {
			offsetYDelta = relativeCaretY
		} else if relativeCaretY > 0.0 {
			let maxY = bounds.size.height - settings.initialHeight
			if relativeCaretY > maxY {
				offsetYDelta = relativeCaretY - maxY
			}
		}
		
		if offsetYDelta != 0 {
			offset.y = offset.y + offsetYDelta
			textView.primitiveContentOffset = offset
		}
	}
	
	private func updateUtilityButtonVisibility() {
        guard isAttachmentUploadEnabled, utilityButtonImage != nil else {
            removeUtilityButton()
            return
        }

        insertUtilityButton()
	}
	
	private func updatePlaceholderVisibility() {
        DispatchQueue.mmEnsureMain {
            let shouldHide = !self.textView.text.isEmpty
            self.placeholderLabel.isHidden = shouldHide
        }
	}

	@objc func didPressSendButton() {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self else { return }
            self.delegate?.send(self.text.livechatBasicPayload, completion: { _ in })
            self.text = ""
        }
	}
	
	@objc func didPressUtilityButton() {
        resignFirstResponder() 
        delegate?.attachmentButtonTapped()
	}
	
	var textHeight: CGFloat {
		return CGFloat(ceilf(Float(textView.sizeThatFits(
            CGSize(width: textView.frame.size.width,
                   height: CGFloat.greatestFiniteMagnitude)).height))
        )
	}
	
	private func postNotification(name: String, userInfo: [String: Any]) {
		NotificationCenter.default.post(
            name: NSNotification.Name(rawValue: name),
            object: self, userInfo: userInfo
        )
	}
	
	private func shifTextFieldInDirection(_ direction: Int8) {
        let fDirection = CGFloat(direction)
        let bWidth = settings.utilityButtonWidth
        let hSpacing = consts.kHorizontalSpacing
		var textContainerFrame = textContainer.frame
		textContainerFrame.size.width = textContainerFrame.size.width - fDirection * (bWidth + hSpacing)
		textContainerFrame.origin.x = textContainerFrame.origin.x + fDirection * (bWidth + hSpacing)
		textContainer.frame = textContainerFrame
	}
	
	private func insertUtilityButton() {
        guard utilityButton.superview == nil else { return }
        shifTextFieldInDirection(+1)
		let ub: UIButton = self.utilityButton
		var utilityButtonFrame = ub.frame
		utilityButtonFrame.origin.x = consts.kHorizontalSpacing
		utilityButtonFrame.origin.y = frame.size.height - settings.utilityButtonHeight - settings.utilityButtonBottomMargin
		ub.frame = utilityButtonFrame
		addSubview(ub)
	}
	
	private func removeUtilityButton() {
        guard utilityButton.superview != nil else { return }
        shifTextFieldInDirection(-1)
		utilityButton.removeFromSuperview()
	}
	
}
