//
//  CPMessageComposingViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14.04.2020.
//

import Foundation

open class MMMessageComposingViewController: MMKeyboardAwareScrollViewController, MMComposeBarDelegate, UIGestureRecognizerDelegate,
                                                UIScrollViewDelegate, UINavigationControllerDelegate {
    let userInputDebounceTimeMs = 250.0
    lazy var draftPostponer = MMPostponer(executionQueue: DispatchQueue.main)
    var scrollingRecognizer: UIPanGestureRecognizer!
    var lastComposingStateSentDateTime: TimeInterval = MobileMessaging.date.now.timeIntervalSinceReferenceDate
    var composeBarView: MMChatComposer! {
        didSet {
            composeBarView.delegate = self
        }
    }
    var docImportMenu: UIDocumentPickerViewController!
    var documentAction = UIDocumentInteractionController()
    var chatMessageCountUpdatedBlock: ((_ count: Int, _ unread: Int) -> Void)?
    var isComposeBarVisible: Bool = false
    internal var settings: MMChatSettings? {
        return MMChatSettings.sharedInstance
    }
    internal var advSettings: MMAdvancedChatSettings {
      return settings?.advancedSettings ?? MMAdvancedChatSettings()
    }
    fileprivate var isVeryFirstRefetch: Bool = true
    fileprivate var isScrollToBottomNeeded: Bool = false
    fileprivate var isScrollToBottomEnabled: Bool = true

    deinit {
        if let composeBar = composeBarView as? ComposeBar {
            composeBar.delegate = nil
        }
    }

    var lastIndexPath: IndexPath?

    override open func viewDidLoad() {
        scrollingRecognizer = UIPanGestureRecognizer(target: self, action: #selector(MMMessageComposingViewController.handlePanning))
        scrollingRecognizer.delegate = self
        setupComposerBar()
        dismissKeyboardIfViewTapped(self.scrollView)
        super.viewDidLoad()
    }

    override open func viewWillDisappear(_ animated: Bool) {
        composeBarView.resignFirstResponder()
        super.viewWillDisappear(animated)
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollToBottomIfNeeded()
    }

    func setupComposerBar() {
        // composeBarView could come defined as custom view, in which case we skip the internal setup
        if composeBarView == nil {
            let viewBounds = view.bounds
            let frame = CGRect(x: 0,
                               y: viewBounds.size.height - advSettings.initialHeight - safeAreaInsets.bottom,
                               width: viewBounds.size.width,
                               height: advSettings.initialHeight)
            let composeBar = ComposeBar(frame: frame, settings: advSettings)
            composeBar.maxLinesCount = 5
            composeBar.placeholder = ChatLocalization.localizedString(forKey: "mm_send_message_placeholder", defaultString: "Send a message")
            composeBar.alpha = 1
            composeBarView = composeBar
            brandComposer()
        }
        scrollView.delegate = self
        view.addSubview(composeBarView)
        updateViewsFor(safeAreaInsets: safeAreaInsets, safeAreaLayoutGuide: view.safeAreaLayoutGuide)
    }
    
    public func sendText(_ text: String, completion: @escaping (NSError?) -> Void) { /* override */ }
    public func sendAttachmentData(_ data: Data, completion: @escaping (_ error: NSError?) -> Void) { /* override */ }
    public func textDidChange(_ text: String?, completion: @escaping (_ error: NSError?) -> Void) { /* override */ }
    public func attachmentButtonTapped() { /* override */ }
    public func composeBarWillChangeFrom(_ startFrame: CGRect, to endFrame: CGRect,
                                         duration: TimeInterval, animationCurve: UIView.AnimationCurve) { /* override */ }
    public func composeBarDidChangeFrom(_ startFrame: CGRect, to endFrame: CGRect) { /* override */ }
    
    internal func brandComposer() {
        guard let composeBarView = composeBarView as? ComposeBar else { return }
        composeBarView.textView.backgroundColor = advSettings.textInputBackgroundColor
        composeBarView.textView.font = MMChatSettings.getMainFont()
        composeBarView.textView.textColor = MMChatSettings.getMainTextColor()
        composeBarView.textView.tintColor = advSettings.typingIndicatorColor
        composeBarView.charCountLabel.font = MMChatSettings.getCharCountFont()
        composeBarView.backgroundView.barTintColor = settings?.backgroungColor ?? UIColor(white: 1, alpha: 1)
        composeBarView.backgroundView.tintColor = settings?.backgroungColor ?? UIColor(white: 1, alpha: 1)
        composeBarView.backgroundView.isHidden = advSettings.isLineSeparatorHidden
        composeBarView.placeholderLabel.font = MMChatSettings.getMainFont()
        composeBarView.placeholderLabel.textColor = MMChatSettings.getMainPlaceholderTextColor()
        composeBarView.sendButton.setImage(MMChatSettings.getSendButtonIcon()?.withRenderingMode(.alwaysTemplate), for: .normal)
        composeBarView.sendButton.imageView?.contentMode = .scaleAspectFit
        composeBarView.utilityButtonImage = MMChatSettings.getAttachmentButtonIcon()?.withRenderingMode(.alwaysTemplate)
        composeBarView.textView.layer.cornerRadius = advSettings.textContainerCornerRadius
    }
        
    override func updateViewsFor(safeAreaInsets: UIEdgeInsets, safeAreaLayoutGuide: UILayoutGuide) {
        var composeBarFrame = composeBarView.frame
        composeBarFrame.y = view.bounds.height - (composeBarFrame.height + safeAreaInsets.bottom)
        composeBarView.frame = composeBarFrame
        scrollViewContainer.frame = view.bounds.inset(
            by: UIEdgeInsets(top: safeAreaInsets.top, left: 0,
                             bottom: (isComposeBarVisible ? composeBarView.cp_h : 0) + safeAreaInsets.bottom, right: 0))
    }

    //MARK: keyboard
    override func keyboardWillShow(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
        super.keyboardWillShow(duration, curve: curve, options: options, height: height)
        updateComposeBarYAnimated(duration, options, height)
    }

    override func keyboardWillHide(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
        super.keyboardWillHide(duration, curve: curve, options: options, height: height)
        updateComposeBarYAnimated(duration, options, height)
    }
    
    private func updateComposeBarYAnimated(_ duration: TimeInterval, _ options: UIView.AnimationOptions, _ bottomOffset: CGFloat) {
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            self.composeBarView.frame.y = self.view.frame.height - bottomOffset
        }, completion: nil)
    }

    //MARK: gestures
    @objc func handlePanning() {
        composeBarView.resignFirstResponder()
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = gestureRecognizer.velocity(in: self.scrollView)
            let result = velocity.y > 200 && abs(velocity.y) > abs(velocity.x)
            return result
        }
        return false
    }

    //MARK: scrolling
    func scrollToBottomIfNeeded() {
        let scrolledFromBottom = fabsf(Float(scrollView.contentOffset.y + scrollView.bounds.height - scrollView.contentSize.height - scrollView.contentInset.bottom))
        let doStickToBottom = scrolledFromBottom < 20
        if doStickToBottom || isVeryFirstRefetch {
            isVeryFirstRefetch = false
            if scrollView.contentSize.height > scrollView.frame.size.height {
                let offset = CGPoint(x: 0, y: scrollView.contentSize.height - scrollView.frame.size.height + scrollView.contentInset.bottom)
                scrollView.contentOffset = offset
            }
        }
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isScrollToBottomEnabled = false
        invalidateScrollingTimer()
    }

    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            resolveScrollingEnabled()
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        resolveScrollingEnabled()
    }

    func resolveScrollingEnabled() {
        invalidateScrollingTimer()
        let scrolledFromBottom = fabsf(Float(scrollView.contentOffset.y + scrollView.bounds.height - scrollView.contentSize.height - scrollView.contentInset.bottom))
        isScrollToBottomEnabled = scrolledFromBottom < 20

        if !isScrollToBottomEnabled {
            timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(MMMessageComposingViewController.resetAutoScrollingEnabled), userInfo: nil, repeats: false)
        }
    }

    @objc func resetAutoScrollingEnabled() {
        if !isScrollToBottomEnabled {
            isScrollToBottomEnabled = true
        }
    }

    func invalidateScrollingTimer() {
        if timer.isValid {
            timer.invalidate()
        }
    }

    var timer = Timer()
}
