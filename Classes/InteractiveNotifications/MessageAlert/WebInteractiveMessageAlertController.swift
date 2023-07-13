import Foundation
import WebKit

/// Shows a new-style in-app message using a webView.
class WebInteractiveMessageAlertController: UIViewController,
                                            WKNavigationDelegate,
                                            MiscEventListener,
                                            UserInteractionEventListener {
    struct Options {
        static func makeDefault () -> Self {
            Options(cornerRadius: MMInteractiveMessageAlertSettings.cornerRadius)
        }
        
        let cornerRadius: Float
    }
    
    private static let nibName = "WebInteractiveMessageAlertController"
    private static let initialHeight = 100.0
    private static let margin = 8.0
    
    private let message: MMInAppMessage
    private let mode: Mode
    
    unowned var delegate: InAppMessageDelegate?
    private let msgView: WebInAppMessageView
    
    /// Timer which schedules automatic dismiss of `msgView` if there is no user interaction
    private var mgsViewAutoDismissTimer: Timer?
    
    // MARK: - Script Interaction
    private let scriptEventRecipient: ScriptEventRecipient
    private let scriptMethodInvoker: ScriptMethodInvoker
    
    // MARK: - Fullscreen Constraints
    private var msgViewHeightToSafeArea: NSLayoutConstraint! // priority: 800
    
    // MARK: - Fullscreen and Popup Constraints
    private var msgViewCenterYToSafeArea: NSLayoutConstraint! // priority: 800
    /// The constraint which prevents `msgView` from going above the safe area.
    private var msgViewTopWithinSafeArea: NSLayoutConstraint! // priority: 800
    /// The constraint which prevents `msgView` from going below the safe area.
    private var msgViewBottomWithinSafeArea: NSLayoutConstraint! // priority: 800
    
    // MARK: -
    /// The constraint which defines specific height of `msgView`.
    private var msgViewHeight: NSLayoutConstraint! // priority 700
    private var msgViewTopMargin: NSLayoutConstraint! // priority 1000
    private var msgViewBottomMargin: NSLayoutConstraint! // priority 1000
    
    // MARK: - Init
    init(
        message: MMInAppMessage,
        webViewWithHeight: WebViewWithHeight?,
        options: Options = Options.makeDefault()) {
        self.message = message
        
        if let webViewWithHeight {
            msgView = WebInAppMessageView(webView: webViewWithHeight.webView)
            mode = .preloadedWebViewWithHeightProvided(webViewWithHeight.height)
        } else {
            msgView = WebInAppMessageView(webView: WKWebView())
            mode = .fromScratch
        }
        
        msgView.cornerRadius = CGFloat(options.cornerRadius)
                    
        scriptEventRecipient = ScriptEventRecipient(webView: msgView.webView)
        scriptMethodInvoker = ScriptMethodInvoker(webView: msgView.webView)
        
        super.init(nibName: WebInteractiveMessageAlertController.nibName, bundle: MobileMessaging.resourceBundle)
        
        modalPresentationStyle = UIModalPresentationStyle.overFullScreen
        modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        
        scriptEventRecipient.listener = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Controller Lifecycle
    override func viewDidLoad() {
        self.view.addSubview(msgView)
        
        msgView.translatesAutoresizingMaskIntoConstraints = false
        initializeStaticConstraints()
        initializeDynamicConstraints()
        
        configureMsgViewConstraints()
        
        switch mode {
        case .preloadedWebViewWithHeightProvided(let height):
            msgViewHeight.constant = height
        case .fromScratch:
            msgView.webView.navigationDelegate = self
            msgView.webView.load(URLRequest(url: message.url))
        }
        
        msgView.webView.scrollView.alwaysBounceVertical = false
        msgView.webView.scrollView.alwaysBounceHorizontal = false
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        configureMsgViewConstraints()
    }
    
    // MARK: - Actions
    @IBAction func onBackgroundTap(_ sender: UITapGestureRecognizer) {
        dismissAndNotifyDelegate()
    }
    
    // MARK: - Static Utils
    private static func setPriority(_ priority: Float, toConstraints constraints: [NSLayoutConstraint]) {
        for constraint in constraints {
            constraint.priority = UILayoutPriority(priority)
        }
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        scriptMethodInvoker.readBodyHeight { [self] height, error in
            guard let height else { return }
            msgViewHeight.constant = height
        }
    }
    
    // MARK: - UserInteractionEventListener
    func scriptEventRecipientDidDetectOpenBrowser(withUrl url: String) {
        dismiss(animated: true) {
            self.delegate?.inAppMessageDidReceiveAction(MMNotificationAction.PrimaryActionId,
                                                               internalDataKey: Consts.InternalDataKeys.browserUrl,
                                                               url: url)
        }
    }
    
    func scriptEventRecipientDidDetectOpenWebView(withUrl url: String) {
        dismiss(animated: true) {
            self.delegate?.inAppMessageDidReceiveAction(MMNotificationAction.PrimaryActionId,
                                                               internalDataKey: Consts.InternalDataKeys.webViewUrl,
                                                               url: url)
        }
    }
    
    func scriptEventRecipientDidDetectOpenAppPage(withDeeplink deeplink: String) {
        dismiss(animated: true) {
            self.delegate?.inAppMessageDidReceiveAction(MMNotificationAction.PrimaryActionId,
                                                               internalDataKey: Consts.InternalDataKeys.deeplink,
                                                               url: deeplink)
        }
    }
    
    func scriptEventRecipientDidDetectClose() {
        dismiss(animated: true) {
            self.delegate?.inAppMessageDidClose()
        }
    }
    
    // MARK: - MiscEventListener
    func scriptEventRecipientDidDetectChangeOfHeight(_ height: Double) {
        let heightPts = height * self.view.contentScaleFactor
        self.msgViewHeight.constant = heightPts
    }
    
    func scriptEventRecipientDidDetectDocumentState(_ state: DocumentReadyState) {
        // pass
    }
    
    // MARK: - Private
    /// Sets active state for all constraints.
    private static func setActiveState(_ active: Bool, toConstraints constraints: [NSLayoutConstraint]) {
        for constraint in constraints {
            constraint.isActive = active
        }
    }
    
    /// Initializes constraints which are static in a sense that they hold forever and never need to be adjusted again.
    private func initializeStaticConstraints() {
        let constraints = [
            // Constraint which centers the message view horizontally.
            msgView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            
            // Constraint which defines specific width of `msgView`.
            msgView.widthAnchor.constraint(equalToConstant: calculateInAppMessageWidth(
                superFrame: view.frame,
                margin: WebInteractiveMessageAlertController.margin))
        ]
        WebInteractiveMessageAlertController.setPriority(800, toConstraints: constraints)
        NSLayoutConstraint.activate(constraints)
        
        let horizontalMarginConstraints = [
            msgView.leftAnchor.constraint(greaterThanOrEqualTo: view.leftAnchor,
                                          constant: WebInteractiveMessageAlertController.margin),
            msgView.rightAnchor.constraint(lessThanOrEqualTo: view.rightAnchor,
                                           constant: -WebInteractiveMessageAlertController.margin),
        ]
        
        WebInteractiveMessageAlertController.setPriority(1000, toConstraints: horizontalMarginConstraints)
        NSLayoutConstraint.activate(horizontalMarginConstraints)
    }
    
    /// Initializes constraints which need to be customized dynamically so references to them are stored as members.
    private func initializeDynamicConstraints() {
        msgViewHeightToSafeArea = msgView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor)
        msgViewCenterYToSafeArea = msgView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        msgViewTopWithinSafeArea = msgView.topAnchor.constraint(
            greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor)
        msgViewBottomWithinSafeArea = msgView.topAnchor.constraint(
            lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor)
        
        WebInteractiveMessageAlertController.setPriority(800, toConstraints:
                                                            [msgViewHeightToSafeArea,
                                                             msgViewCenterYToSafeArea,
                                                             msgViewTopWithinSafeArea,
                                                             msgViewBottomWithinSafeArea
                                                            ]
        )
        
        msgViewHeight = msgView.heightAnchor.constraint(
            equalToConstant: WebInteractiveMessageAlertController.initialHeight)
        WebInteractiveMessageAlertController.setPriority(700, toConstraints: [msgViewHeight])
        
        msgViewTopMargin = msgView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor,
                                                        constant: WebInteractiveMessageAlertController.margin)
        msgViewBottomMargin = msgView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor,
                                                              constant: -WebInteractiveMessageAlertController.margin)
        
        msgViewTopMargin.isActive = true
        msgViewBottomMargin.isActive = true
    }
    
    private func configureMsgViewConstraints() {
        NSLayoutConstraint.deactivate([
            msgViewHeightToSafeArea,
            msgViewCenterYToSafeArea,
            msgViewTopWithinSafeArea,
            msgViewBottomWithinSafeArea,
            msgViewHeight,
        ])
        if (message.type == .fullscreen) {
            msgViewHeightToSafeArea.isActive = true
            msgViewCenterYToSafeArea.isActive = true
        } else {
            msgViewHeight.isActive = true
            msgViewCenterYToSafeArea.isActive = true
            msgViewTopWithinSafeArea.isActive = true
            msgViewBottomWithinSafeArea.isActive = true
        }
    }
    
    @objc
    private func dismissAndNotifyDelegate() {
        dismiss(animated: true) { self.delegate?.inAppMessageDidDismiss() }
    }
}

private enum Mode {
    case preloadedWebViewWithHeightProvided(CGFloat)
    case fromScratch
}
