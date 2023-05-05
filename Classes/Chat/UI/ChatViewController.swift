//
//  CPWebViewChatViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14.04.2020.
//

import WebKit

///Key component to use for displaying In-app chat view.
///We support two ways to quickly embed it into your own application:
/// - via Interface Builder: set it as `Custom class` for your view controller object.
/// - programmatically: use one of the `make` methods provided.
open class MMChatViewController: MMMessageComposingViewController, ChatWebViewDelegate, ChatSettingsApplicable, NamedLogger {
    
    ///Will make UINavigationController with ChatViewController as root
    public static func makeRootNavigationViewController() -> MMChatNavigationVC {
        return MMChatNavigationVC.makeChatNavigationViewController()
    }
    
    //Will make ChatViewController, for usage in navigation
    public static func makeChildNavigationViewController() -> MMChatViewController {
        return MMChatViewController(type: .back)
    }
    
    ///Will make UINavigationController with ChatViewController as root with custom transition
    public static func makeRootNavigationViewControllerWithCustomTransition() -> MMChatNavigationVC {
        return MMChatNavigationVC.makeChatNavigationViewController(transitioningDelegate: ChatCustomTransitionDelegate())
    }
    
    //Will make ChatViewController, for presenting modally
    public static func makeModalViewController() -> MMChatViewController {
        return MMChatViewController(type: .dismiss)
    }
    
    //Will make ChatViewController with a custom composeBar view
    public static func makeCustomViewController(with inputView: MMChatComposer) -> MMChatViewController {
        let vc = MMChatViewController()
        vc.composeBarView = inputView
        return vc
    }
    
    var webView: ChatWebView!
    private var chatWidget: ChatWidget?
    
    override var scrollView: UIScrollView! {
        return webView.scrollView
    }
    
    override var scrollViewContainer: UIView! {
        return webView
    }
    
    var chatNotAvailableLabel: ChatNotAvailableLabel!
    var isChattingInMultithread: Bool = false
    var initialBackButtonVisibility: Bool = true
    var initialLeftNavigationItem: UIBarButtonItem?
    
    open override func loadView() {
        super.loadView()
        setupWebView()
        setupChatNotAvailableLabel()
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        MobileMessaging.inAppChat?.webViewDelegate = self
        didEnableControls(false)
        registerToChatSettingsChanges()
        let bckgColor = settings?.backgroungColor ?? .white
        webView.backgroundColor = bckgColor
        view.backgroundColor = bckgColor
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        draftPostponer.postponeBlock(delay: 0) { [weak self] in
            if let composeBar = self?.composeBarView as? ComposeBar {
                self?.webView.sendDraft(composeBar.text)
            } else {
                self?.webView.sendDraft("")
            }
        }
        super.viewWillDisappear(animated)
    }
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MobileMessaging.inAppChat?.isChatScreenVisible = true
        MobileMessaging.inAppChat?.resetMessageCounter()
        if chatWidget?.isMultithread ?? false, !self.navigationItem.hidesBackButton {
           handleMultithreadBackButton(appearing: true)
        }
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        MobileMessaging.inAppChat?.isChatScreenVisible = false
        if chatWidget?.isMultithread ?? false, !initialBackButtonVisibility {
           handleMultithreadBackButton(appearing: false)
        }
    }
    
    private lazy var chatAttachmentPicker: ChatAttachmentPicker = ChatAttachmentPicker(delegate: self)
    
    private func handleMultithreadBackButton(appearing: Bool) {
        if appearing {
            initialLeftNavigationItem = self.navigationItem.leftBarButtonItem
            initialBackButtonVisibility = self.navigationItem.hidesBackButton
            self.navigationItem.hidesBackButton = true
            let customButton = settings?.multithreadBackButton
            let backButton = UIBarButtonItem(image: customButton?.image ?? UIImage(mm_chat_named: "backButton"),
                                             style: customButton?.style ?? UIBarButtonItem.Style.plain,
                                             target: customButton?.target ?? self,
                                             action: customButton?.action ?? #selector(onInterceptedBackTap))
            self.navigationItem.leftBarButtonItem = backButton
        } else {
            self.navigationItem.leftBarButtonItem = initialLeftNavigationItem
            self.navigationItem.hidesBackButton = initialBackButtonVisibility
        }
    }
    
    //ChatSettingsApplicable
    func applySettings() {
        guard let settings = settings else {
            return
        }
        
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            
            if let navBarColor = settings.navBarColor {
                appearance.backgroundColor = navBarColor
            }
            
            if let navBarTitleColor = settings.navBarTitleColor {
                appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: navBarTitleColor]
            }
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        } else {
            navigationController?.navigationBar.isTranslucent = false
            
            if let navBarColor = settings.navBarColor {
                navigationController?.navigationBar.backgroundColor = navBarColor
            }
            
            if let navBarTitleColor = settings.navBarTitleColor {
                navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : navBarTitleColor]
            }
        }
        
        if let navBarColor = settings.navBarColor {
            navigationController?.navigationBar.barTintColor = navBarColor
        }
        
        if let navBarItemsTintColor = settings.navBarItemsTintColor {
            navigationController?.navigationBar.tintColor = navBarItemsTintColor
        }
        
        title = settings.title
        
        if let sendButtonTintColor = settings.sendButtonTintColor,
        let composerBar = composeBarView as? ComposeBar {
            composerBar.sendButtonTintColor = sendButtonTintColor
            composerBar.utilityButtonTintColor = sendButtonTintColor
        }
    }

    public func showThreadsList() {
        webView.showThreadsList(completion: { [weak self] error in
            if let error = error {
                self?.logError(error.description)
            }
        })
    }
              
    @objc private func onInterceptedBackTap() {
        // When multithread is in use, the user experience and the actual navigation follow different logic.
        // When going from thread list to a thread, the navigation happens in the webView. In order to handle the expected
        // action of going "back", we interpret the chat webview state and decide if we actuall pop from navigation
        // or we invoke a method in the chat widget to go back to the thread list.
        if isChattingInMultithread {
            showThreadsList()
        } else if presentingViewController != nil {
            dismiss(animated: true) // viewController is a modal
        } else {
            navigationController?.popViewController(animated: true) // regular presentation
        }
    }
    
    // ChatWebViewDelegate
    func didLoadWidget(_ widget: ChatWidget) {
        chatWidget = widget
        webView.loadWidget(widget)
        isComposeBarVisible = !(widget.isMultithread ?? false)
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.setLanguage()
        webView.addViewChangedListener(completion: { [weak self] error in
            if let error = error {
                self?.logError(error.description)
            }
            return
        })
    }
    
    func didEnableControls(_ enabled: Bool) {
        webView.isUserInteractionEnabled = enabled
        webView.isLoaded = enabled
        if let composeBar = composeBarView as? ComposeBar {
            composeBar.isEnabled = enabled
        }
        if enabled {
            MobileMessaging.inAppChat?.resetMessageCounter()
        }
    }
    
    override var isComposeBarVisible: Bool {
        didSet {
            if oldValue != isComposeBarVisible {
                setComposeBarVisibility(isVisible: isComposeBarVisible)
            } else if !isComposeBarVisible && !composeBarView.isHidden {
                // In some cases (ie the first time a multithread widget is loaded), we want to hide the
                // composer without animation.
                DispatchQueue.main.async {
                    self.composeBarView.isHidden = true
                }
            }
        }
    }
    
    func didShowComposeBar(_ visible: Bool) {
        guard !(chatWidget?.isMultithread ?? false) else { return }
        isComposeBarVisible = visible
    }
    
    func setComposeBarVisibility(isVisible: Bool) {
        if isVisible {
            DispatchQueue.main.async {
                self.composeBarView.isHidden = false
            }
        }
        UIView.animate(
            withDuration: 0.3,
            delay: .zero,
            options: UIView.AnimationOptions.curveEaseIn,
            animations: { [weak self] () -> Void in
                if let composeBarView = self?.composeBarView, let webView = self?.webView {
                    webView.frame = CGRect(
                        x: webView.frame.x,
                        y: webView.frame.y,
                        width: webView.frame.width,
                        height: webView.frame.height + (isVisible ? -composeBarView.bounds.height : composeBarView.bounds.height))
                    composeBarView.frame = CGRect(
                        x: composeBarView.frame.x,
                        y: webView.frame.y + webView.frame.height,
                        width: composeBarView.frame.width,
                        height: composeBarView.frame.height)
                }
            },
            completion: { [weak self] (Bool) -> Void in
                if !isVisible, let composeBarView = self?.composeBarView {
                    composeBarView.isHidden = true
                    composeBarView.resignFirstResponder()
                }
            }
        )
    }
    
    override func keyboardWillShow(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
        if composeBarView.isFirstResponder {
            super.keyboardWillShow(duration, curve: curve, options: options,
                                   height: height + (isComposeBarVisible ? composeBarView.bounds.height : 0)
            )
        }
    }
    
    override func keyboardWillHide(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
        super.keyboardWillHide(duration, curve: curve, options: options,
                               height: (isComposeBarVisible ? composeBarView.bounds.height : 0) + self.safeAreaInsets.bottom
        )
    }
    
    func didReceiveError(_ errors: ChatErrors) {
        if errors == .none {
            chatNotAvailableLabel.setVisibility(false, text: nil)
            if !(webView.isLoaded) {
                webView.reload()
            }
        } else {
            chatNotAvailableLabel.setVisibility(true, text: errors.localizedDescription)
        }
    }
    
    func didOpenPreview(forAttachment attachment: ChatWebAttachment) {
        let vc =  AttachmentPreviewController.makeRootInNavigationController(forAttachment: attachment)
        self.present(vc, animated: true, completion: nil)
    }
    
    // Private
    private func setupWebView() {
        webView = ChatWebView(frame: view.bounds)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
    }
    
    private func setupChatNotAvailableLabel() {
        chatNotAvailableLabel = ChatNotAvailableLabel(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 0))
        chatNotAvailableLabel.font = MMChatSettings.getMainFont()
        chatNotAvailableLabel.backgroundColor = settings?.errorLabelBackgroundColor ?? .lightGray
        chatNotAvailableLabel.textColor = settings?.errorLabelTextColor ?? .black
        chatNotAvailableLabel.numberOfLines = ChatNotAvailableLabel.kMaxNumberOfLines
        chatNotAvailableLabel.isHidden = true
        self.view.addSubview(self.chatNotAvailableLabel)
    }
    
    /// Method for sending metadata to conversations backend. It can be called any time, many times, but once the chat has started and is presented.
    /// The format of the metadata must be that of Javascript objects and values (for guidance, it must be a string accepted by JSON.stringify()
    /// The multiThreadStrategy is entirely optional and we recommented to leave as default ACTIVE.
    @objc public func sendContextualData(_ metadata: String, multiThreadStrategy: MMChatMultiThreadStrategy = .ACTIVE,
                                         completion: @escaping (_ error: NSError?) -> Void) {
        webView.sendContextualData(metadata, multiThreadStrategy: multiThreadStrategy, completion: completion)
    }

    func didChangeView(_ state: MMChatWebViewState) {
        guard chatWidget?.isMultithread ?? false else {
            isComposeBarVisible = true
            isChattingInMultithread = false
            return
        }
        isComposeBarVisible = state == .loadingThread || state == .thread || state == .singleThreadMode
        isChattingInMultithread = state == .loadingThread || state == .thread || state == .closedThread
    }
    
    // MARK: MMComposeBarDelegate delegate
    public override func sendText(_ text: String, completion: @escaping (_ error: NSError?) -> Void) {
        webView.sendMessage(text, attachment: nil, completion: completion)
    }
    
    public override func sendAttachmentData(_ data: Data, completion: @escaping (_ error: NSError?) -> Void) {
        webView.sendMessage(nil, attachment: ChatMobileAttachment(data: data), completion: completion)
    }
    
    public override func textDidChange(_ text: String?, completion: @escaping (_ error: NSError?) -> Void) {
        draftPostponer.postponeBlock(delay: userInputDebounceTimeMs) { [weak self] in
            self?.webView.sendDraft(text, completion: completion)
        }
    }
    
    public override func attachmentButtonTapped() {
        chatAttachmentPicker.present(presentationController: self)
    }
    
    public override func composeBarWillChangeFrom(_ startFrame: CGRect, to endFrame: CGRect,
                                         duration: TimeInterval, animationCurve: UIView.AnimationCurve) {
        let heightDelta = startFrame.height - endFrame.height
        scrollViewContainer?.frame.height += heightDelta;
    }
    
    public override func composeBarDidChangeFrom(_ startFrame: CGRect, to endFrame: CGRect) {}
}

extension MMChatViewController: ChatAttachmentPickerDelegate {
    func didSelect(attachment: ChatMobileAttachment) {
        webView.sendMessage(attachment: attachment)
    }
    
    func permissionNotGranted(permissionKeys: [String]?) {
        guard let permissionKeys = permissionKeys else {
            return
        }
        var accessDescription: String? = nil
        for key in permissionKeys {
            if let permissionDescription = Bundle.main.object(forInfoDictionaryKey: key) as? String {
                accessDescription = accessDescription != nil ? "\(accessDescription!)\n\(permissionDescription)" : permissionDescription
            }
        }
        let alert = UIAlertController(title: accessDescription ?? "Required permissions not granted",
                                      message: ChatLocalization.localizedString(forKey: "mm_permissions_alert_message", defaultString: "To give permissions go to Settings"),
                                      preferredStyle: .alert)
        alert.view.tintColor = MMChatSettings.getMainTextColor()
        alert.addAction(UIAlertAction(title: MMLocalization.localizedString(forKey: "mm_button_cancel", defaultString: "Cancel"), style: .cancel, handler: nil))
        if let settingsUrl = NSURL(string: UIApplication.openSettingsURLString, relativeTo: nil) as URL?,
           UIApplication.shared.canOpenURL(settingsUrl) {
            alert.addAction(UIAlertAction(title: ChatLocalization.localizedString(forKey: "mm_button_settings", defaultString: "Settings"), style: .default, handler: { (action) in
                UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
            }))
        }
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func validateAttachmentSize(size: Int) -> Bool {
        return size <= maxUploadAttachmentSize
    }
    
    func attachmentSizeExceeded() {
        let title = ChatLocalization.localizedString(forKey: "mm_attachment_upload_failed_alert_title", defaultString: "Attachment upload failed")
        let message = ChatLocalization.localizedString(forKey: "mm_attachment_upload_failed_alert_message", defaultString: "Maximum allowed size exceeded")
        logError("\(title). \(message) (\(maxUploadAttachmentSize.mbSize))")
        showAlert(title, message: message)
    }
    
    private var maxUploadAttachmentSize: UInt { return chatWidget?.maxUploadContentSize ?? ChatAttachmentUtils.DefaultMaxAttachmentSize}
}

extension MMChatViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url, UIApplication.shared.canOpenURL(url) else {
            decisionHandler(.allow)
            return
        }
        logDebug("will open URL: \(url)")
        UIApplication.shared.open(url)
        decisionHandler(.cancel)
    }
}
