//
//  CPMessageComposingViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14.04.2020.
//

import Foundation

open class MMMessageComposingViewController: MMKeyboardAwareScrollViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate, UINavigationControllerDelegate {

    lazy var composeBarDelegate = MMComposeBarDelegate(
        scrollViewContainer: self.scrollViewContainer,
        sendTextBlock: { [weak self] text in
            self?.didTapSendText(text)
        },
        utilityButtonClickedBlock: { [weak self] in
            self?.utilityButtonClicked()
        },
        textViewDidChangedBlock: { [weak self] text in
            self?.textViewDidChange(text)
        }
    )

    var scrollingRecognizer: UIPanGestureRecognizer!
    var lastComposingStateSentDateTime: TimeInterval = MobileMessaging.date.now.timeIntervalSinceReferenceDate
    var composeBarView: ComposeBar!
    var docImportMenu: UIDocumentPickerViewController!
    var documentAction = UIDocumentInteractionController()
    var chatMessageCountUpdatedBlock: ((_ count: Int, _ unread: Int) -> Void)?

    fileprivate var isVeryFirstRefetch: Bool = true
    fileprivate var isScrollToBottomNeeded: Bool = false
    fileprivate var isScrollToBottomEnabled: Bool = true

    deinit {
        composeBarView?.delegate = nil
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
        composeBarDelegate.draftPostponer.postponeBlock(delay: 0) { [weak self] in
            self?.composeBarDelegate.textViewDidChangedBlock(self?.composeBarView.text ?? "")
        }
        super.viewWillDisappear(animated)
    }

    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollToBottomIfNeeded()
    }

    func setupComposerBar() {
        let viewBounds = view.bounds
        let frame = CGRect(x: 0,
                           y: viewBounds.size.height - ComposeBarConsts.initialHeight - safeAreaInsets.bottom,
                           width: viewBounds.size.width,
                           height: ComposeBarConsts.initialHeight)
        composeBarView = ComposeBar(frame: frame)
        composeBarView.maxLinesCount = 5
        composeBarView.placeholder = ChatLocalization.localizedString(forKey: "mm_send_message_placeholder", defaultString: "Send a message")
        composeBarView.delegate = composeBarDelegate
        composeBarView.alpha = 1
        view.addSubview(composeBarView)

        scrollViewContainer.frame = view.bounds.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: composeBarView.cp_h + safeAreaInsets.bottom, right: 0))
        scrollView.delegate = self
        composeBarView.utilityButtonImage = UIImage(mm_named: "attachmentButton")?.withRenderingMode(.alwaysTemplate)
    }
    
    override func updateViewsFor(safeAreaInsets: UIEdgeInsets, safeAreaLayoutGuide: UILayoutGuide) {
        var composeBarFrame = composeBarView.frame
        guard composeBarFrame.maxY > safeAreaLayoutGuide.layoutFrame.maxY else {
            return
        }
        composeBarFrame.y = view.bounds.height - (composeBarFrame.height + safeAreaInsets.bottom)
        composeBarView.frame = composeBarFrame
        var scrollViewContainerFrame = scrollViewContainer.frame
        scrollViewContainerFrame.height = view.bounds.height - (composeBarFrame.height + safeAreaInsets.bottom)
        scrollViewContainer.frame = scrollViewContainerFrame
    }

    func didTapSendText(_ text: String) {
        // override
    }
    
    func textViewDidChange(_ text: String) {
        // override
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
        
    func utilityButtonClicked() {}
}
