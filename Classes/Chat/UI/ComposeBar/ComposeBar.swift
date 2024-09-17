//
//  ComposeBar.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 08/12/2017.
//
import Foundation
import UIKit

struct ComposeBarConsts {
	// runtime consts
	static var kTextViewLineHeight: CGFloat = 0.0
	static var kTextViewFirstLineHeight: CGFloat = 0.0
	static var kTextViewToSuperviewHeightDelta: CGFloat = 0.0
	
	static let kResizeAnimationCurve 		= UIView.AnimationCurve.easeInOut
	static let kResizeAnimationOptions 		= UIView.AnimationOptions.curveEaseInOut
	static let kResizeAnimationDuration: CGFloat 	= 0.25
	static let kHorizontalSpacing: CGFloat          	=  4.0
	static let kFontSize: CGFloat                   	= 16.0
	static let kTextContainerTopMargin: CGFloat     	=  8.0
	static let kTextContainerBottomMargin: CGFloat  	=  8.0
	static let kTextContainerLeftPadding: CGFloat   	=  3.0
	static let kTextContainerRightPadding: CGFloat  	=  2.0
	static let kTextContainerTopPadding: CGFloat    	=  4.0
	static let kTextContainerCornerRadius: CGFloat  	= 0.0
	static let kTextViewTopMargin: CGFloat          	= -8.0
	static let kPlaceholderHeight: CGFloat          	= 25.0
	static let kPlaceholderSideMargin: CGFloat      	=  8.0
	static let kPlaceholderTopMargin: CGFloat       	=  2.0
	static let kButtonHeight: CGFloat               	= 32.0
	static let kButtonTouchableOverlap: CGFloat     	=  6.0
	static let kButtonRightMargin: CGFloat          	= 8.0
	static let kButtonBottomMargin: CGFloat         	=  8.0
	static let kUtilityButtonWidth: CGFloat         	= 32.0
	static let kUtilityButtonHeight: CGFloat        	= 32.0
	static let kUtilityButtonBottomMargin: CGFloat  	=  6.0
	static let kCaretYOffset: CGFloat               	=  7.0
	static let kCharCountFontSize: CGFloat          	= 11.0
	static let kCharCountTopMargin: CGFloat			    = 15.0
	static let kInitialHeight: CGFloat 				    = 44.0
    static let kMainTextColor: UIColor                  = .black
    static let kMainPlaceholderTextColor: UIColor       = UIColor(hue: 240/360, saturation: 0.02, brightness: 0.8, alpha: 1.0)
    static let kTextInputBackgroundColor: UIColor       = .clear
    static let kTypingIndicatorColor: UIColor           = .black
    static let kSendButtonIcon: UIImage?                = UIImage(mm_chat_named: "sendButton")
    static let kAttachmentButtonIcon: UIImage?          = UIImage(mm_chat_named: "attachmentButton")
    static let kIsLineSeparatorHidden: Bool             = false
    static let kMainFont: UIFont                        = UIFont.systemFont(ofSize: ComposeBarConsts.kFontSize)
    static let kCharCountFont: UIFont                   = UIFont.systemFont(ofSize: ComposeBarConsts.kCharCountFontSize)
	
	struct Notifications {
		static let didChangeFrameNotification = "ComposeBarDidChangeFrameNotification"
		static let willChangeFrameNotification = "ComposeBarWillChangeFrameNotification"
		
		struct Keys {
			static let animationDurationUserInfoKey = "ComposeAnimationDurationUserInfoKey"
			static let animationCurveUserInfoKey = "ComposeAnimationCurveUserInfoKey"
			static let frameBeginUserInfoKey = "ComposeBarFrameBeginUserInfoKey"
			static let frameEndUserInfoKey = "ComposeBarFrameEndUserInfoKey"
		}
	}
}

class ComposeBar: UIView, MMChatComposer, UITextViewDelegate {
    public var composeBarSettings: MMAdvancedChatSettings = MMAdvancedChatSettings()
    private var textBuffer : [String] = []

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
    
	lazy var sendButton: ComposeBar_Send_Button! = {
		let ret = ComposeBar_Send_Button()
		ret.frame = CGRect(x: self.bounds.size.width - ComposeBarConsts.kHorizontalSpacing - composeBarSettings.buttonRightMargin - composeBarSettings.buttonTouchableOverlap, y: self.bounds.size.height - composeBarSettings.buttonBottomMargin - composeBarSettings.buttonHeight, width: 2 * composeBarSettings.buttonTouchableOverlap, height: composeBarSettings.buttonHeight)
		ret.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
		ret.addTarget(self, action: #selector(ComposeBar.didPressSendButton), for: .touchUpInside)
		return ret
	}()
    
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
	
	private var _sendButtonTitle: String?
	public var buttonTitle: String? {
		get {
			if _sendButtonTitle == nil {
                _sendButtonTitle = MMLocalization.localizedString(forKey: "Send", defaultString: "Send")
			}
			return _sendButtonTitle
		}
		set {
			if newValue != _sendButtonTitle {
				_sendButtonTitle = newValue
				sendButton.setTitle(newValue, for: .normal)
				resizeSendButton()
			}
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
	public var maxCharCount: UInt = 0 {
		didSet {
			updateCharCountLabel()
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
			let maxTextHeight = maxHeight - composeBarSettings.initialHeight + ComposeBarConsts.kTextViewLineHeight
			return maxTextHeight / ComposeBarConsts.kTextViewLineHeight
		}
		set {
			let maxTextHeight = newValue * ComposeBarConsts.kTextViewLineHeight
			let maxHeight = maxTextHeight - ComposeBarConsts.kTextViewLineHeight + composeBarSettings.initialHeight
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
		ret.minimumScaleFactor = UIFont.smallSystemFontSize / ComposeBarConsts.kFontSize
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
		ret.frame = CGRect(x: 0, y: self.bounds.size.height - composeBarSettings.utilityButtonHeight - composeBarSettings.utilityButtonBottomMargin, width: composeBarSettings.utilityButtonWidth, height: composeBarSettings.utilityButtonHeight)
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

	//MARK: - Public methods
	
	public func setText(_ txt: String, animated: Bool) {
		textView.text = txt
		handleTextViewChangeAnimated(animated)
	}
	
	// priv
	lazy var backgroundView: UIToolbar! = {
		var frame = self.bounds
		frame.origin.y = 0.5
		let ret = UIToolbar(frame: frame)
		ret.barStyle = .default
		ret.isTranslucent = false
		ret.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		return ret
	}()
	lazy var charCountLabel: UILabel! = {
		let ret = UILabel(frame: CGRect(x: 0, y: ComposeBarConsts.kCharCountTopMargin, width: self.bounds.size.width - 8, height: 20))
		ret.isHidden = self.maxCharCount == 0
		ret.textAlignment = .right
		ret.textColor = UIColor(hue: 240/360, saturation: 0.02, brightness: 0.8, alpha: 1)
		ret.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		return ret
	}()

	lazy var textContainer: UIButton! = {
        let textContainerFrame = CGRect(x: ComposeBarConsts.kHorizontalSpacing, y:
			composeBarSettings.textContainerTopMargin, width:
			self.bounds.size.width - ComposeBarConsts.kHorizontalSpacing * 3 - composeBarSettings.buttonRightMargin, height:
											   self.bounds.size.height - composeBarSettings.textContainerTopMargin - composeBarSettings.textContainerBottomMargin)
		let ret = UIButton(type: .custom)
		ret.frame = textContainerFrame
		ret.clipsToBounds = true
		ret.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		let txtH = self.textHeight
		self.previousTextHeight = txtH
		var textViewFrame = textContainerFrame
		textViewFrame.origin.x = composeBarSettings.textContainerLeftPadding
		textViewFrame.origin.y = composeBarSettings.textContainerTopPadding + composeBarSettings.textViewTopMargin
		textViewFrame.size.width = textViewFrame.size.width - composeBarSettings.textContainerLeftPadding - composeBarSettings.textContainerRightPadding
		textViewFrame.size.height = self.textHeight
		self.textView.frame = textViewFrame
		ret.addSubview(self.textView)
		
		let placeholderFrame = CGRect(x: composeBarSettings.placeholderSideMargin, y: composeBarSettings.placeholderTopMargin, width: textContainerFrame.size.width - 2 * composeBarSettings.placeholderSideMargin, height: composeBarSettings.placeholderHeight)
		
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
        self.composeBarSettings = settings
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
		updateCharCountLabel()
		resizeTextViewIfNeededAnimated(false)
	}
	
	//MARK: - UITextViewDelegate
	
	func textViewDidChange(_ textView: UITextView) {
		handleTextViewChangeAnimated(false)
        delegate?.textDidChange(text, completion: { _ in })
	}
	
	//MARK: - public properties
	
	//MAKR: - privates
	private func calculateRuntimeConstants() {
		if (ComposeBarConsts.kTextViewFirstLineHeight == 0 && ComposeBarConsts.kTextViewLineHeight == 0 && ComposeBarConsts.kTextViewToSuperviewHeightDelta == 0) {
            ComposeBarConsts.kTextViewFirstLineHeight = textHeight
			textView.text = "\n"
            ComposeBarConsts.kTextViewLineHeight = textHeight - ComposeBarConsts.kTextViewFirstLineHeight
			textView.text = ""
            ComposeBarConsts.kTextViewToSuperviewHeightDelta = CGFloat(ceilf(Float(composeBarSettings.initialHeight) - Float(ComposeBarConsts.kTextViewFirstLineHeight)))
		}
	}
	
	private func setup() {
		autoAdjustTopOffset = true
		isEnabled = true
		maxHeight = 200.0
		autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
		addSubview(backgroundView)
		addSubview(charCountLabel)
		addSubview(sendButton)
		addSubview(textContainer)
        textView.delegate = self
		resizeSendButton()
	}
	
	private func updateSendButtonEnabled() {
		let enabled = isEnabled && textView.text.count > 0
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
			min(th + ComposeBarConsts.kTextViewToSuperviewHeightDelta, mh),
			composeBarSettings.initialHeight
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
		
		let animationDuration = ComposeBarConsts.kResizeAnimationDuration * animationDurationFactor
		
		let willChangeUserInfo: [String: Any] = [
			ComposeBarConsts.Notifications.Keys.frameBeginUserInfoKey: NSValue.init(cgRect: frameBegin),
			ComposeBarConsts.Notifications.Keys.frameEndUserInfoKey: NSValue.init(cgRect: frameEnd),
			ComposeBarConsts.Notifications.Keys.animationDurationUserInfoKey: animationDuration,
			ComposeBarConsts.Notifications.Keys.animationCurveUserInfoKey: ComposeBarConsts.kResizeAnimationCurve
		]
		
		let didChangeUserInfo: [String: Any] = [
			ComposeBarConsts.Notifications.Keys.frameBeginUserInfoKey: NSValue.init(cgRect: frameBegin),
			ComposeBarConsts.Notifications.Keys.frameEndUserInfoKey: NSValue.init(cgRect: frameEnd)
		]
		
		let afterAnimation: (Bool) -> Void = {[weak self] _ in
			self?.postNotification(name: ComposeBarConsts.Notifications.didChangeFrameNotification, userInfo: didChangeUserInfo)
            self?.delegate?.composeBarDidChangeFrom(frameBegin, to: frameEnd)
		}
		
		postNotification(name: ComposeBarConsts.Notifications.willChangeFrameNotification, userInfo: willChangeUserInfo)
        delegate?.composeBarWillChangeFrom(frameBegin, to: frameEnd, duration: TimeInterval(animationDuration), animationCurve: ComposeBarConsts.kResizeAnimationCurve)
		
		if animated {
			UIView.animate(withDuration: TimeInterval(ComposeBarConsts.kResizeAnimationDuration * animationDurationFactor), delay: 0, options: ComposeBarConsts.kResizeAnimationOptions, animations: animation, completion: afterAnimation)
		} else {
			animation()
			afterAnimation(true)
		}
	}
	
	private func updateCharCountLabel() {
        DispatchQueue.mmEnsureMain {
            let isHidden = self.maxCharCount == 0 || self.textHeight == ComposeBarConsts.kTextViewFirstLineHeight
            self.charCountLabel.isHidden = isHidden
            if !isHidden {
                let count = self.textView.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).count
                self.charCountLabel.text = "\(count)/\(self.maxCharCount)"
            }
        }
	}
	
	private func handleTextViewChangeAnimated(_ animated: Bool) {
		updatePlaceholderVisibility()
		resizeTextViewIfNeededAnimated(animated)
		scrollToCaretIfNeeded()
		updateCharCountLabel()
		updateSendButtonEnabled()
	}
	
	private func resizeSendButton() {
		let previousButtonFrame = sendButton.frame
		var newButtonFrame = previousButtonFrame
		var textContainerFrame = textContainer.frame
		var charCountLabelFrame = charCountLabel.frame
		
        sendButton.sizeToFit()
		
		let widthDelta = sendButton.bounds.size.width + 2 * composeBarSettings.buttonTouchableOverlap - previousButtonFrame.size.width
		
		newButtonFrame.size.width = newButtonFrame.size.width + widthDelta
		newButtonFrame.origin.x = newButtonFrame.origin.x - widthDelta
        sendButton.frame = newButtonFrame
		
		textContainerFrame.size.width = textContainerFrame.size.width - widthDelta
		textContainer.frame = textContainerFrame
		
		charCountLabelFrame.origin.x = textContainerFrame.origin.x + textContainerFrame.size.width
		charCountLabelFrame.size.width = bounds.size.width - charCountLabelFrame.origin.x - ComposeBarConsts.kHorizontalSpacing
		charCountLabel.frame = charCountLabelFrame
	}
		
	private func scrollToCaretIfNeeded() {
		guard superview != nil, let selectedTextRange = textView.selectedTextRange, !selectedTextRange.isEmpty else
		{
			return
		}
		
		let position = selectedTextRange.start
		var offset = textView.contentOffset
		let relativeCaretY: CGFloat = textView.caretRect(for: position).origin.y - offset.y - ComposeBarConsts.kCaretYOffset
		var offsetYDelta: CGFloat = 0.0
		if relativeCaretY < 0.0 {
			offsetYDelta = relativeCaretY
		} else if relativeCaretY > 0.0 {
			let maxY = bounds.size.height - composeBarSettings.initialHeight
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
		if utilityButtonImage != nil && utilityButton.superview == nil {
			shifTextFieldInDirection(+1)
			insertUtilityButton()
		} else if utilityButtonImage == nil && utilityButton.superview != nil  {
			shifTextFieldInDirection(-1)
			removeUtilityButton()
		}
	}
	
	private func updatePlaceholderVisibility() {
        DispatchQueue.mmEnsureMain {
            let shouldHide = !self.textView.text.isEmpty
            self.placeholderLabel.isHidden = shouldHide
        }
	}

    private func handleTextBuffer() {
        precondition(Thread.isMainThread, "Not on main thread")
        guard let text = textBuffer.first else { return }
        textBuffer.removeFirst()
        delegate?.sendText(text, completion: { error in
            guard error == nil else { return }
            DispatchQueue.main.async { [weak self] in
                self?.handleTextBuffer()
            }
        })
    }

	@objc func didPressSendButton() {
        // When a string longer than the max length is sent, we'll cut it into fragments of max length (or less) and send
        // them as individual messages, in order. This only applies to the default ComposerBar. Custom composers will
        // just trigger the chat's delegate method "textLengthExceeded" and not send.
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self else { return }
            let max = Int(ChatAttachmentUtils.DefaultMaxTextLength)
            self.textBuffer.append(contentsOf: self.text.mm_components(withMaxLength: max))
            self.handleTextBuffer()
            self.text = ""
        }
	}
	
	@objc func didPressUtilityButton() {
        resignFirstResponder() 
        delegate?.attachmentButtonTapped()
	}
	
	var textHeight: CGFloat {
		return CGFloat(ceilf(Float(textView.sizeThatFits(CGSize(width: textView.frame.size.width, height: CGFloat.greatestFiniteMagnitude)).height)))
	}
	
	private func postNotification(name: String, userInfo: [String: Any]) {
		NotificationCenter.default.post(name: NSNotification.Name(rawValue: name), object: self, userInfo: userInfo)
	}
	
	private func shifTextFieldInDirection(_ direction: Int8) {
		var textContainerFrame = textContainer.frame
		textContainerFrame.size.width = textContainerFrame.size.width - CGFloat(direction) * (composeBarSettings.utilityButtonWidth + ComposeBarConsts.kHorizontalSpacing)
		textContainerFrame.origin.x = textContainerFrame.origin.x + CGFloat(direction) * (composeBarSettings.utilityButtonWidth + ComposeBarConsts.kHorizontalSpacing)
		textContainer.frame = textContainerFrame
	}
	
	private func insertUtilityButton() {
		let ub: UIButton = self.utilityButton
		var utilityButtonFrame = ub.frame
		utilityButtonFrame.origin.x = ComposeBarConsts.kHorizontalSpacing
		utilityButtonFrame.origin.y = frame.size.height - composeBarSettings.utilityButtonHeight - composeBarSettings.utilityButtonBottomMargin
		ub.frame = utilityButtonFrame
		addSubview(ub)
	}
	
	private func removeUtilityButton() {
		utilityButton.removeFromSuperview()
	}
	
	
}
