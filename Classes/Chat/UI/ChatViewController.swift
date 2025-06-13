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
    
    ///Will make UINavigationController with ChatViewController as root with custom MMChatComposer
    public static func makeRootNavigationViewController(with inputView: MMChatComposer, customTransitionDelegate: Bool = false) -> MMChatNavigationVC {
        return MMChatNavigationVC.makeChatNavigationViewController(transitioningDelegate: customTransitionDelegate ? ChatCustomTransitionDelegate() : nil, inputView: inputView)
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

    private var webViewHandler: ChatWebViewHandler?

    var webView: ChatWebView! {
        return webViewHandler?.webView
    }

    public private(set) var chatWidget: ChatWidget? {
        get { return webViewHandler?.chatWidget }
        set { webViewHandler?.chatWidget = newValue }
    }

    public var messagesViewFrame: CGRect {
        set {
            webView.frame = newValue
        }
        get {
            return webView.frame
        }
    }

    public var chatInputViewFrame: CGRect? {
        set {
            composeBarView?.frame = newValue ?? .zero
        }

        get {
            return composeBarView?.frame
        }
    }
    
    override var scrollView: UIScrollView! {
        return webView.scrollView
    }
    
    override var scrollViewContainer: UIView! {
        return webView
    }
    
    var chatNotAvailableLabel: ChatNotAvailableLabel!
    public private(set) var isChattingInMultithread: Bool = false
    var initialBackButtonIsHidden: Bool = true
    var initialLeftNavigationItem: UIBarButtonItem?
    var initialLargeDisplayMode: UINavigationItem.LargeTitleDisplayMode = .automatic
    private var firstTimeHandlingMultithread = true
    private var didSetOnMessageReceivedListener = false

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
        setBackgroundSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(appBecomeActive), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appBecomeInactive), name: UIApplication.didEnterBackgroundNotification, object: nil)

    }

    private func setBackgroundSettings() {
        let bckgColor = settings?.backgroundColor ?? .white
        webView.backgroundColor = bckgColor
        webView.isOpaque = false
        webView.scrollView.backgroundColor = MMChatSettings.sharedInstance.chatInputSeparatorLineColor ?? bckgColor
        view.backgroundColor = bckgColor
    }

    open override func viewWillDisappear(_ animated: Bool) {
        draftPostponer.postponeBlock(delay: 0) { [weak self] in
            let text = (self?.composeBarView as? ComposeBar)?.text
            self?.send((text ?? "").livechatDraftPayload, completion: { _ in })
        }
        super.viewWillDisappear(animated)
    }
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MobileMessaging.inAppChat?.isChatScreenVisible = true
        MobileMessaging.inAppChat?.resetMessageCounter()
        if chatWidget?.multiThread ?? false {
           handleMultithreadBackButton(appearing: true)
        }
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        MobileMessaging.inAppChat?.isChatScreenVisible = false
    }
    
    private lazy var chatAttachmentPicker: ChatAttachmentPicker = ChatAttachmentPicker(
        delegate: self, allowedContentTypes: self.chatWidget?.attachments.allowedExtensions ?? [])

    private func handleMultithreadBackButton(appearing: Bool) {
        if appearing {
            if firstTimeHandlingMultithread {
                initialLeftNavigationItem = self.navigationItem.leftBarButtonItem
                initialBackButtonIsHidden = self.navigationItem.hidesBackButton
                initialLargeDisplayMode = self.navigationItem.largeTitleDisplayMode
                firstTimeHandlingMultithread = false
            }
            self.navigationItem.hidesBackButton = true
            let customButton = settings?.multithreadBackButton
            let backButton = UIBarButtonItem(image: customButton?.image ?? UIImage(mm_chat_named: "backButton"),
                                             style: customButton?.style ?? UIBarButtonItem.Style.plain,
                                             target: customButton?.target ?? self,
                                             action: customButton?.action ?? #selector(onInterceptedBackTap))
            self.navigationItem.leftBarButtonItem = backButton
            hideLeftButton(!isChattingInMultithread && (self.navigationItem.backBarButtonItem == nil || initialBackButtonIsHidden))
        } else {
            hideLeftButton(true) // this works as a reset for the custom left button we did create
            self.navigationItem.leftBarButtonItem = initialLeftNavigationItem
            self.navigationItem.hidesBackButton = initialBackButtonIsHidden
         }
    }

    private func hideLeftButton(_ hidden: Bool) {
        if #available(iOS 16.0, *) {
            navigationItem.leftBarButtonItem?.isHidden = hidden
            if navigationController?.navigationBar.prefersLargeTitles ?? false {
                navigationItem.largeTitleDisplayMode = hidden ? initialLargeDisplayMode : .never
                navigationController?.navigationBar.sizeToFit()
            }
        } // else not possible on older version - nothing changed
    }

    private var isLeftButtonHidden: Bool {
        if #available(iOS 16.0, *) {
            return navigationItem.leftBarButtonItem?.isHidden ?? false
        } else {
            return false // on prior OS we cannot hide left button on multithread (ie when chat is its own rootVC). Important to note that we are not replacing the navigationItem.backButtonItem here, but the leftBarButtonItem, to have full control over it
        }
    }

    //ChatSettingsApplicable
    func applySettings() {
        guard let settings = settings else {
            return
        }

        setNavBarBranding(settings)
        title = settings.title

        if let sendButtonTintColor = settings.sendButtonTintColor,
        let composerBar = composeBarView as? ComposeBar {
            composerBar.sendButtonTintColor = sendButtonTintColor
            composerBar.utilityButtonTintColor = sendButtonTintColor
        }
        
        brandComposer()
        setBackgroundSettings()
    }

    private func setNavBarBranding(_ settings: MMChatSettings) {
        guard MMChatSettings.sharedInstance.shouldSetNavBarAppearance else { return }
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

        if let navBarColor = settings.navBarColor {
            navigationController?.navigationBar.barTintColor = navBarColor
        }

        if let navBarItemsTintColor = settings.navBarItemsTintColor {
            navigationController?.navigationBar.tintColor = navBarItemsTintColor
        }
    }
              
    @objc private func onInterceptedBackTap() {
        // When multithread is in use, the user experience and the actual navigation follow different logic.
        // When going from thread list to a thread, the navigation happens in the webView. In order to handle the expected
        // action of going "back", we interpret the chat webview state and decide if we actuall pop from navigation
        // or we invoke a method in the chat widget to go back to the thread list.
        guard !isChattingInMultithread else {
            showThreadsList()
            return
        }

        if chatWidget?.multiThread ?? false {
           handleMultithreadBackButton(appearing: false) // actual back action. We do not trigger this in viewDidDisappear because we could recognise wrong a pushing of new VC instead of a popping of current (remember, we are intercepting the back action with a left button replacement)
        }

        if presentingViewController != nil {
            dismiss(animated: true) // viewController is a modal
        } else {
            navigationController?.popViewController(animated: true) // regular presentation
        }
    }
    
    public func stopConnection() {
        webViewHandler?.stopConnection()
    }
    
    public func restartConnection() {
        webViewHandler?.restartConnection()
    }
    
    // ChatWebViewDelegate
    func didLoadWidget(_ widget: ChatWidget) {
        chatWidget = widget
        webViewHandler?.ensureWidgetLoaded { [weak self] error in
            self?.isComposeBarVisible = !(widget.multiThread ?? false) // multithread displays first a list of threads, without input.
            (self?.composeBarView as? ComposeBar)?.isAttachmentUploadEnabled = widget.attachments.isEnabled
            self?.webViewHandler?.triggerPendingActions(with: error)
        }
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.addViewChangedListener(completion: { [weak self] error in
            if let error = error {
                self?.logError(error.description)
            }
            return
        })
    }
    
    func sendCachedContextData() {
        guard let contextualData = MMInAppChatService.sharedInstance?.contextualData else {
            return
        }
        
        MMInAppChatService.sharedInstance?.contextualData = nil
        sendContextualData(contextualData)
    }

    func addOnMessageReceivedListener() {
        if MobileMessaging.inAppChat?.onRawMessageReceived != nil, !didSetOnMessageReceivedListener {
            webView.addMessageReceivedListener(completion: { [weak self] error in
                if let error = error {
                    self?.logError(error.description)
                }
                self?.didSetOnMessageReceivedListener = true
                return
            })
        }
    }

    public func setLanguage(_ language: MMLanguage, completion: @escaping (_ error: NSError?) -> Void) {
        webViewHandler?.setLanguage(language, completion: { error in completion(error as? NSError) })
    }

    public func setWidgetTheme(_ themeName: String, completion: @escaping (_ error: NSError?) -> Void) {
        webViewHandler?.setWidgetTheme(themeName, completion: { error in completion(error as? NSError) })
    }

    func didEnableControls(_ enabled: Bool) {
        webView.isUserInteractionEnabled = enabled
        webView.isLoaded = enabled
        if enabled {
            MMInAppChatService.sharedInstance?.obtainChatRegistrations()
        }
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
                DispatchQueue.mmEnsureMain {
                    self.setComposeBarVisibility(isVisible: self.isComposeBarVisible)
                }
            } else if !isComposeBarVisible && !(composeBarView?.isHidden ?? true) {
                // In some cases (ie the first time a multithread widget is loaded), we want to hide the
                // composer without animation.
                DispatchQueue.mmEnsureMain {
                    self.composeBarView?.isHidden = true
                }
            }
        }
    }
    
    func didShowComposeBar(_ visible: Bool) {
        guard !(chatWidget?.multiThread ?? false) else { return }
        isComposeBarVisible = visible
    }
    
    func setComposeBarVisibility(isVisible: Bool) {
        guard !MMChatSettings.sharedInstance.shouldUseExternalChatInput else {
            composeBarView?.isHidden = !isVisible
            return
        }
        if isVisible {
            DispatchQueue.mmEnsureMain {
                self.composeBarView?.isHidden = false
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

    override func updateViewsFor(safeAreaInsets: UIEdgeInsets, safeAreaLayoutGuide: UILayoutGuide) {
        guard MMChatSettings.sharedInstance.shouldSetNavBarAppearance else { return }
        super.updateViewsFor(safeAreaInsets: safeAreaInsets, safeAreaLayoutGuide: safeAreaLayoutGuide)
    }

    override func setupComposerBar() {
        guard !MMChatSettings.sharedInstance.shouldUseExternalChatInput else { return }
        super.setupComposerBar()
    }

    override func keyboardWillShow(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
        guard MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance, let composeBarView = composeBarView else { return }
        if composeBarView.isFirstResponder {
            super.keyboardWillShow(duration, curve: curve, options: options,
                                   height: height + (isComposeBarVisible ? composeBarView.bounds.height : 0)
            )
        }
    }
    
    override func keyboardWillHide(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
        guard MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance, let composeBarView = composeBarView  else { return }
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
            let exception = MMChatException(code: errors.rawValue, name: errors.rawDescription, message: errors.localizedDescription, retryable: true)
            switch MMInAppChatService.sharedInstance?.delegate?.didReceiveException?(exception) ?? .displayDefaultAlert {
            case .displayDefaultAlert:
                chatNotAvailableLabel.setVisibility(true, text: errors.localizedDescription)
            default:
                break
            }
        }
    }
    
    func didOpenPreview(forAttachment attachment: ChatWebAttachment) {
        let vc =  AttachmentPreviewController.makeRootInNavigationController(forAttachment: attachment)
        self.present(vc, animated: true, completion: nil)
    }
    
    // Private
    private func setupWebView() {
        let webView = ChatWebView(frame: view.bounds)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
        
        self.webViewHandler = ChatWebViewHandler(webView: webView)
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
    
    @objc private func appBecomeActive() {
        restartConnection()
    }
    
    @objc private func appBecomeInactive() {
        stopConnection()
    }
    /// Method for sending metadata to conversations backend. It can be called any time, many times, but once the chat has started and is presented.
    /// The format of the metadata must be that of Javascript objects and values (for guidance, it must be a string accepted by JSON.stringify()
    /// The multiThreadStrategy is entirely optional and we recommented to leave as default ACTIVE.
    @objc public func sendContextualData(_ metadata: String, multiThreadStrategy: MMChatMultiThreadStrategy = .ACTIVE,
                                         completion: @escaping (_ error: NSError?) -> Void) {
        webViewHandler?.sendContextualData(metadata, multiThreadStrategy: multiThreadStrategy, completion: { error in completion(error as? NSError) })
    }

    public func didChangeView(_ state: MMChatWebViewState) {
        if !(chatWidget?.multiThread ?? false) {
            isComposeBarVisible = true
            isChattingInMultithread = false
        } else {
            isComposeBarVisible = state == .loadingThread || state == .thread || state == .singleThreadMode
            isChattingInMultithread = state == .loadingThread || state == .thread || state == .closedThread
        }

        if chatWidget?.multiThread ?? false {
            hideLeftButton(!isChattingInMultithread && (self.navigationItem.backBarButtonItem == nil || initialBackButtonIsHidden))
        }

        if state != .loading && state != .loadingThread && state != .unknown {
            // In case actions are pending, we finally trigger them successfully if the view state just became valid.
            webViewHandler?.triggerPendingActions(with: nil)
            sendCachedContextData()
            addOnMessageReceivedListener()
        }

        webViewHandler?.currentViewState = state
        MMInAppChatService.sharedInstance?.delegate?.chatDidChange?(to: state)
    }
    
    // MARK: MMComposeBarDelegate delegate
    @available(*, deprecated, message: "Method 'send' needs to be used instead. This method will be removed in a future release")
    public override func sendText(_ text: String, completion: @escaping (_ error: NSError?) -> Void) {
        webViewHandler?.send(text.livechatBasicPayload, completion: { error in completion(error as? NSError) })
    }
    // Sends a draft message to be shown in a chat-to-peer chat.
    @available(*, deprecated, message: "Method 'send' needs to be used instead. This method will be removed in a future release")
    public override func sendDraft(_ message: String?, completion: @escaping (NSError?) -> Void) {
        webViewHandler?.send((message ?? "").livechatDraftPayload, completion: { error in completion(error as? NSError) })
    }

    @available(*, deprecated, message: "Method 'send' needs to be used instead. This method will be removed in a future release")
    public override func sendAttachment(_ fileName: String? = nil, data: Data, completion: @escaping (_ error: NSError?) -> Void) {
        let payload = MMLivechatBasicPayload(fileName: fileName, data: data)
        webViewHandler?.send(payload, completion: { error in completion(error as? NSError) })
    }

    public override func send(_ payload: MMLivechatPayload, completion: @escaping (_ error: NSError?) -> Void) {
        webViewHandler?.send(payload, completion: { error in completion(error as? NSError) })
    }

    public override func textDidChange(_ text: String?, completion: @escaping (_ error: NSError?) -> Void) {
        draftPostponer.postponeBlock(delay: userInputDebounceTimeMs) { [weak self] in
            self?.send((text ?? "").livechatDraftPayload, completion: { _ in })
        }
    }
    
    public override func attachmentButtonTapped() {
        chatAttachmentPicker.present(
            presentationController: self,
            sourceView: (composeBarView as? ComposeBar)?.utilityButton)
    }
    
    public override func composeBarWillChangeFrom(_ startFrame: CGRect, to endFrame: CGRect,
                                         duration: TimeInterval, animationCurve: UIView.AnimationCurve) {
        let heightDelta = startFrame.height - endFrame.height
        scrollViewContainer?.frame.height += heightDelta;
    }
    
    public override func composeBarDidChangeFrom(_ startFrame: CGRect, to endFrame: CGRect) {}

    ///If your chat widget allows a list of multiple threads, this method will return whether the back action must pop your view or be ignored (so only
    ///the internal chat navigation handles the "back" action)
    public func onCustomBackPressed() -> Bool {
        if isChattingInMultithread {
            showThreadsList()
            return false
        } else {
            return true
        }
    }
    
    func sendContextualData(_ contextualData: ContextualData) {
        self.sendContextualData(contextualData.metadata, multiThreadStrategy: contextualData.multiThreadStrategy) { _ in }
    }

}

extension MMChatViewController: ChatAttachmentPickerDelegate {
    func didSelect(filename: String?, data: Data) {
        let payload = MMLivechatBasicPayload(fileName: filename, data: data)
        self.send(payload, completion: { _ in })
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
        let alert = UIAlertController.mmInit(
            title: accessDescription ?? "Required permissions not granted",
            message: ChatLocalization.localizedString(forKey: "mm_permissions_alert_message", defaultString: "To give permissions go to Settings"),
            preferredStyle: .alert,
            sourceView: self.view)
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

    func validateTextLength(size: Int) -> Bool {
        return size <= ChatAttachmentUtils.DefaultMaxTextLength
    }

    @objc
    internal func attachmentSizeExceeded() {
        guard let externalSizeExceededHandling = MMInAppChatService.sharedInstance?.delegate?.attachmentSizeExceeded else {
            let title = ChatLocalization.localizedString(forKey: "mm_attachment_upload_failed_alert_title", defaultString: "Attachment upload failed")
            let message = ChatLocalization.localizedString(forKey: "mm_attachment_upload_failed_alert_message", defaultString: "Maximum allowed size exceeded")
            logError("\(title). \(message) (\(maxUploadAttachmentSize.mbSize))")
            showAlert(title, message: message)
            return
        }
        externalSizeExceededHandling(maxUploadAttachmentSize)
    }

    private var maxUploadAttachmentSize: UInt {
        return chatWidget?.attachments.maxSize ?? ChatAttachmentUtils.DefaultMaxAttachmentSize
    }
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

extension MMChatViewController: MMLiveChatThreadsActions {
    public func showThreadsList(completion: @escaping ((any Error)?) -> Void) {
        webViewHandler?.showThreadsList(completion: completion)
    }
    
    public func getThreads(completion: @escaping (Swift.Result<[MMLiveChatThread], any Error>) -> Void) {
        webViewHandler?.getThreads(completion: completion)
    }
    
    public func openThread(with id: String, completion: @escaping (Swift.Result<MMLiveChatThread, any Error>) -> Void) {
        webViewHandler?.openThread(with: id, completion: completion)
    }
    
    public func getActiveThread(completion: @escaping (Swift.Result<MMLiveChatThread?, any Error>) -> Void) {
        webView.getActiveThread(completion: completion)
    }
    
    public func showThreadsList() {
        webViewHandler?.showThreadsList(completion: { [weak self] error in
            if let error = error {
                self?.logError(error.localizedDescription)
            }
        })
    }
}

extension MMChatViewController: MMChatBasiWebViewActions, MMChatInternalWebViewActions {
    public func send(_ payload: any MMLivechatPayload, completion: @escaping ((any Error)?) -> Void) {
        webViewHandler?.send(payload, completion: completion)
    }

    public func createThread(_ payload: MMLivechatPayload, completion: @escaping (MMLiveChatThread?, (any Error)?) -> Void) {
        webViewHandler?.createThread(payload, completion: completion)
    }

    func openNewThread(completion: @escaping ((any Error)?) -> Void) {
        webViewHandler?.openNewThread(completion: completion)
    }
}
