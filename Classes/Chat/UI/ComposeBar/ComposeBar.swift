//
//  ComposeBar.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 08/12/2017.
//


struct ComposeBarConsts {
	// runtime consts
	static var kTextViewLineHeight: CGFloat = 0.0
	static var kTextViewFirstLineHeight: CGFloat = 0.0
	static var kTextViewToSuperviewHeightDelta: CGFloat = 0.0

	
	static let kResizeAnimationCurve 		= UIView.AnimationCurve.easeInOut
	static let kResizeAnimationOptions 		= UIView.AnimationOptions.curveEaseInOut
	static let kResizeAnimationDuration: CGFloat 	= 0.25
	static let kHorizontalSpacing: CGFloat          	=  8.0
	static let kFontSize: CGFloat                   	= 17.0
	static let kTextContainerTopMargin: CGFloat     	=  8.0
	static let kTextContainerBottomMargin: CGFloat  	=  8.0
	static let kTextContainerLeftPadding: CGFloat   	=  3.0
	static let kTextContainerRightPadding: CGFloat  	=  2.0
	static let kTextContainerTopPadding: CGFloat    	=  4.0
	static let kTextContainerCornerRadius: CGFloat  	= 5.25
	static let kTextViewTopMargin: CGFloat          	= -8.0
	static let kPlaceholderHeight: CGFloat          	= 25.0
	static let kPlaceholderSideMargin: CGFloat      	=  8.0
	static let kPlaceholderTopMargin: CGFloat       	=  2.0
	static let kButtonHeight: CGFloat               	= 26.0
	static let kButtonTouchableOverlap: CGFloat     	=  6.0
	static let kButtonRightMargin: CGFloat          	= -2.0
	static let kButtonBottomMargin: CGFloat         	=  8.0
	static let kUtilityButtonWidth: CGFloat         	= 25.0
	static let kUtilityButtonHeight: CGFloat        	= 25.0
	static let kUtilityButtonBottomMargin: CGFloat  	=  9.0
	static let kCaretYOffset: CGFloat               	=  7.0
	static let kCharCountFontSize: CGFloat          	= 11.0
	static let kCharCountTopMargin: CGFloat			= 15.0
	static let initialHeight: CGFloat 				= 44.0
	
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

@objc protocol ComposeBarDelegate: UITextViewDelegate {
	func composeBarTextViewDidBeginEditing(composeBar: ComposeBar)
	func composeBarTextViewDidChange(composeBar: ComposeBar)
	func composeBarDidPressButton(composeBar: ComposeBar)
	func composeBarDidPressUtilityButton(composeBar: ComposeBar)
	func composeBar(composeBar: ComposeBar, willChangeFromFrame startFrame: CGRect, toFrame endFrame: CGRect, duration: TimeInterval, animationCurve: UIView.AnimationCurve)
	func composeBar(composeBar: ComposeBar, didChangeFromFrame startFrame: CGRect, toFrame endFrame: CGRect)
}

import Foundation

class ComposeBar: UIView, UITextViewDelegate {
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
	lazy var button: UIButton! = {
		let ret = ComposeBar_Button(type: UIButton.ButtonType.custom)
		ret.frame = CGRect(x: self.bounds.size.width - ComposeBarConsts.kHorizontalSpacing - ComposeBarConsts.kButtonRightMargin - ComposeBarConsts.kButtonTouchableOverlap, y: self.bounds.size.height - ComposeBarConsts.kButtonBottomMargin - ComposeBarConsts.kButtonHeight, width: 2 * ComposeBarConsts.kButtonTouchableOverlap, height: ComposeBarConsts.kButtonHeight)
		ret.titleEdgeInsets = UIEdgeInsets(top: 0.5, left: 0, bottom: 0, right: 0)
		ret.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
		ret.setTitle(self.buttonTitle, for: .normal)
		ret.setTitleColor(UIColor(hue: 240/360, saturation: 0.03, brightness: 0.58, alpha: 1), for: .disabled)
		ret.setTitleColor(UIColor(hue: 211/360, saturation: 1, brightness: 1, alpha: 1), for: .normal)
		ret.addTarget(self, action: #selector(ComposeBar.didPressButton), for: .touchUpInside)
		ret.titleLabel?.font = UIFont.boldSystemFont(ofSize: ComposeBarConsts.kFontSize)
		return ret
	}()
	public var buttonTintColor: UIColor? {
		get {
			return button.titleColor(for: .normal)
		}
		set {
			button.setTitleColor(newValue, for: .normal)
		}
	}
	
	private var _buttonTitle: String?
	public var buttonTitle: String? {
		get {
			if _buttonTitle == nil {
				_buttonTitle = MMLocalization.localizedString(forKey: "Send", defaultString: "Send")
			}
			return _buttonTitle
		}
		set {
			if newValue != _buttonTitle {
				_buttonTitle = newValue
				button.setTitle(newValue, for: .normal)
				resizeButton()
			}
		}
	}
	public weak var delegate: ComposeBarDelegate? {
		didSet {
			setupDelegateChainForTextView()
		}
	}
	public var isEnabled: Bool = true {
		didSet {
			textView.isEditable = isEnabled
			updateButtonEnabled()
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
			let maxTextHeight = maxHeight - ComposeBarConsts.initialHeight + ComposeBarConsts.kTextViewLineHeight
			return maxTextHeight / ComposeBarConsts.kTextViewLineHeight
		}
		set {
			let maxTextHeight = maxLinesCount * ComposeBarConsts.kTextViewLineHeight
			let maxHeight = maxTextHeight - ComposeBarConsts.kTextViewLineHeight + ComposeBarConsts.initialHeight
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
		ret.font = UIFont.systemFont(ofSize: ComposeBarConsts.kFontSize)
		ret.textColor = UIColor(hue: 240/360, saturation: 0.02, brightness: 0.8, alpha: 1.0)
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
		ret.backgroundColor = UIColor.clear
		ret.font = UIFont.systemFont(ofSize: ComposeBarConsts.kFontSize)
		return ret
	}()
	lazy var utilityButton: UIButton! = {
		let ret = ComposeBar_Button(type: .custom)
		ret.autoresizingMask = [.flexibleRightMargin, .flexibleTopMargin]
		ret.frame = CGRect(x: 0, y: self.bounds.size.height - ComposeBarConsts.kUtilityButtonHeight - ComposeBarConsts.kUtilityButtonBottomMargin, width: ComposeBarConsts.kUtilityButtonWidth, height: ComposeBarConsts.kUtilityButtonHeight)
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
		ret.barTintColor = UIColor(white: 0.95, alpha: 1)
		ret.tintColor = UIColor(white: 1, alpha: 1)
		ret.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		return ret
	}()
	lazy var topLineView: UIView! = {
		var frame = self.bounds
		frame.size.height = 0.5
		let ret = UIView(frame: frame)
		ret.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
		ret.autoresizingMask = .flexibleWidth
		return ret
	}()
	lazy var charCountLabel: UILabel! = {
		let ret = UILabel(frame: CGRect(x: 0, y: ComposeBarConsts.kCharCountTopMargin, width: self.bounds.size.width - 8, height: 20))
		ret.isHidden = self.maxCharCount == 0
		ret.textAlignment = .right
		ret.font = UIFont.systemFont(ofSize: ComposeBarConsts.kCharCountFontSize)
		ret.textColor = UIColor(hue: 240/360, saturation: 0.02, brightness: 0.8, alpha: 1)
		ret.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
		return ret
	}()
	lazy var textContainer: UIButton! = {
		let textContainerFrame = CGRect(x: ComposeBarConsts.kHorizontalSpacing, y:
			ComposeBarConsts.kTextContainerTopMargin, width:
			self.bounds.size.width - ComposeBarConsts.kHorizontalSpacing * 3 - ComposeBarConsts.kButtonRightMargin, height:
											   self.bounds.size.height - ComposeBarConsts.kTextContainerTopMargin - ComposeBarConsts.kTextContainerBottomMargin)
		let ret = UIButton(type: .custom)
		ret.frame = textContainerFrame
		ret.clipsToBounds = true
		ret.backgroundColor = UIColor.white
		ret.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		let layer = ret.layer
		layer.borderColor = UIColor(hue: 240/360, saturation: 0.02, brightness: 0.8, alpha: 1).cgColor
		layer.borderWidth = 0.5
		layer.cornerRadius = ComposeBarConsts.kTextContainerCornerRadius
		
		let txtH = self.textHeight
		self.previousTextHeight = txtH
		var textViewFrame = textContainerFrame
		textViewFrame.origin.x = ComposeBarConsts.kTextContainerLeftPadding
		textViewFrame.origin.y = ComposeBarConsts.kTextContainerTopPadding + ComposeBarConsts.kTextViewTopMargin
		textViewFrame.size.width = textViewFrame.size.width - ComposeBarConsts.kTextContainerLeftPadding + ComposeBarConsts.kTextContainerRightPadding
		textViewFrame.size.height = self.textHeight
		self.textView.frame = textViewFrame
		ret.addSubview(self.textView)
		
		let placeholderFrame = CGRect(x: ComposeBarConsts.kPlaceholderSideMargin, y: ComposeBarConsts.kPlaceholderTopMargin, width: textContainerFrame.size.width - 2 * ComposeBarConsts.kPlaceholderSideMargin, height: ComposeBarConsts.kPlaceholderHeight)
		
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
		updateButtonEnabled()
		resizeTextViewIfNeededAnimated(false)
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		
		// Correct top line size:
		topLineView.frame = {
			var ret = topLineView.frame
			ret.size.height = 0.5
			return ret
		}()
		
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
		if let delegate = delegate, delegate.responds(to: #selector(ComposeBarDelegate.composeBarTextViewDidChange(composeBar:)))
		{
			delegate.composeBarTextViewDidChange(composeBar: self)
		}
	}
	
	func textViewDidBeginEditing(_ textView: UITextView) {
		if let delegate = delegate, delegate.responds(to: #selector(ComposeBarDelegate.composeBarTextViewDidBeginEditing(composeBar:)))
		{
			delegate.composeBarTextViewDidBeginEditing(composeBar: self)
		}
	}
	
	//MARK: - public properties
	
	//MAKR: - privates
	private func calculateRuntimeConstants() {
		if (ComposeBarConsts.kTextViewFirstLineHeight == 0 && ComposeBarConsts.kTextViewLineHeight == 0 && ComposeBarConsts.kTextViewToSuperviewHeightDelta == 0)
		{
			ComposeBarConsts.kTextViewFirstLineHeight = textHeight
			textView.text = "\n"
			ComposeBarConsts.kTextViewLineHeight = textHeight - ComposeBarConsts.kTextViewFirstLineHeight
			textView.text = ""
			ComposeBarConsts.kTextViewToSuperviewHeightDelta = CGFloat(ceilf(Float(ComposeBarConsts.initialHeight) - Float(ComposeBarConsts.kTextViewFirstLineHeight)))
		}
	}
	
	private func setup() {
		autoAdjustTopOffset = true
		isEnabled = true
		maxHeight = 200.0
		
		autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
		
		addSubview(topLineView)
		addSubview(backgroundView)
		addSubview(charCountLabel)
		addSubview(button)
		addSubview(textContainer)
		setupDelegateChainForTextView()
		
		resizeButton()
	}
	
	private func updateButtonEnabled() {
		let enabled = isEnabled && textView.text.count > 0
		button.isEnabled = enabled
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
			ComposeBarConsts.initialHeight
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
		
		let afterAnimation: (Bool) -> Void = { _ in
			self.postNotification(name: ComposeBarConsts.Notifications.didChangeFrameNotification, userInfo: didChangeUserInfo)
			if let delegate = self.delegate, delegate.responds(to: #selector(ComposeBarDelegate.composeBar(composeBar:didChangeFromFrame:toFrame:)))
			{
				delegate.composeBar(composeBar: self, didChangeFromFrame: frameBegin, toFrame: frameEnd)
			}
		}
		
		postNotification(name: ComposeBarConsts.Notifications.willChangeFrameNotification, userInfo: willChangeUserInfo)
		
		if let delegate = self.delegate, delegate.responds(to: #selector(ComposeBarDelegate.composeBar(composeBar:willChangeFromFrame:toFrame:duration:animationCurve:)))
		{
			delegate.composeBar(composeBar: self, willChangeFromFrame: frameBegin, toFrame: frameEnd, duration: TimeInterval(animationDuration), animationCurve: ComposeBarConsts.kResizeAnimationCurve)
		}
		
		if animated {
			UIView.animate(withDuration: TimeInterval(ComposeBarConsts.kResizeAnimationDuration * animationDurationFactor), delay: 0, options: ComposeBarConsts.kResizeAnimationOptions, animations: animation, completion: afterAnimation)
		} else {
			animation()
			afterAnimation(true)
		}
	}
	
	private func updateCharCountLabel() {
		let isHidden = maxCharCount == 0 || textHeight == ComposeBarConsts.kTextViewFirstLineHeight
		charCountLabel.isHidden = isHidden
		if !isHidden {
			let count = textView.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).count
			charCountLabel.text = "\(count)/\(maxCharCount)"
		}
	}
	
	private func handleTextViewChangeAnimated(_ animated: Bool) {
		updatePlaceholderVisibility()
		resizeTextViewIfNeededAnimated(animated)
		scrollToCaretIfNeeded()
		updateCharCountLabel()
		updateButtonEnabled()
	}
	
	private func resizeButton() {
		let previousButtonFrame = button.frame
		var newButtonFrame = previousButtonFrame
		var textContainerFrame = textContainer.frame
		var charCountLabelFrame = charCountLabel.frame
		
		button.sizeToFit()
		
		let widthDelta = button.bounds.size.width + 2 * ComposeBarConsts.kButtonTouchableOverlap - previousButtonFrame.size.width
		
		newButtonFrame.size.width = newButtonFrame.size.width + widthDelta
		newButtonFrame.origin.x = newButtonFrame.origin.x - widthDelta
		button.frame = newButtonFrame
		
		textContainerFrame.size.width = textContainerFrame.size.width - widthDelta
		textContainer.frame = textContainerFrame
		
		charCountLabelFrame.origin.x = textContainerFrame.origin.x + textContainerFrame.size.width
		charCountLabelFrame.size.width = bounds.size.width - charCountLabelFrame.origin.x - ComposeBarConsts.kHorizontalSpacing
		charCountLabel.frame = charCountLabelFrame
	}
	
	private func setupDelegateChainForTextView() {
		//FIXME:? delegate chain not implemented
		textView.delegate = self
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
			let maxY = bounds.size.height - ComposeBarConsts.initialHeight
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
		let shouldHide = !textView.text.isEmpty
		placeholderLabel.isHidden = shouldHide
	}
	
	@objc func didPressButton() {
		if let delegate = delegate, delegate.responds(to: #selector(ComposeBarDelegate.composeBarDidPressButton(composeBar:))) {
			delegate.composeBarDidPressButton(composeBar: self)
		}
	}
	
	@objc func didPressUtilityButton() {
		if let delegate = delegate, delegate.responds(to: #selector(ComposeBarDelegate.composeBarDidPressUtilityButton(composeBar:))) {
			delegate.composeBarDidPressUtilityButton(composeBar: self)
		}
	}
	
	var textHeight: CGFloat {
		return CGFloat(ceilf(Float(textView.sizeThatFits(CGSize(width: textView.frame.size.width, height: CGFloat.greatestFiniteMagnitude)).height)))
	}
	
	private func postNotification(name: String, userInfo: [String: Any]) {
		NotificationCenter.default.post(name: NSNotification.Name(rawValue: name), object: self, userInfo: userInfo)
	}
	
	private func shifTextFieldInDirection(_ direction: Int8) {
		var textContainerFrame = textContainer.frame
		textContainerFrame.size.width = textContainerFrame.size.width - CGFloat(direction) * (ComposeBarConsts.kUtilityButtonWidth + ComposeBarConsts.kHorizontalSpacing)
		textContainerFrame.origin.x = textContainerFrame.origin.x + CGFloat(direction) * (ComposeBarConsts.kUtilityButtonWidth + ComposeBarConsts.kHorizontalSpacing)
		textContainer.frame = textContainerFrame
	}
	
	private func insertUtilityButton() {
		let ub: UIButton = self.utilityButton
		var utilityButtonFrame = ub.frame
		utilityButtonFrame.origin.x = ComposeBarConsts.kHorizontalSpacing
		utilityButtonFrame.origin.y = frame.size.height - ComposeBarConsts.kUtilityButtonHeight - ComposeBarConsts.kUtilityButtonBottomMargin
		ub.frame = utilityButtonFrame
		addSubview(ub)
	}
	
	private func removeUtilityButton() {
		utilityButton.removeFromSuperview()
	}
	
	
}
