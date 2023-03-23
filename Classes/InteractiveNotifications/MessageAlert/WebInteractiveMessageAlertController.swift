import Foundation
import WebKit

/// Shows a new-style in-app message using a webView.
class WebInteractiveMessageAlertController: UIViewController, InteractiveMessageAlertController, WKNavigationDelegate {
    private enum Mode {
        case preloadedWebViewWithHeightProvided(CGFloat)
        case fromScratch
    }
    
    struct Options {
        static func makeDefault () -> Self {
            Options(cornerRadius: MMInteractiveMessageAlertSettings.cornerRadius)
        }
        
        let cornerRadius: Float
    }
    
    private static let nibName = "WebInteractiveMessageAlertController"
    private static let initialBannerHeight = 100.0
    private static let margin = 8.0
    
    private static let bannerAutoDismissDuration : TimeInterval = 5.0
    private static let bannerAnimationDuration : TimeInterval = 0.5
    private static let bannerAnimationDelayDuration : TimeInterval = 0.0
    private static let bannerAnimationUsingSpringWithDamping : CGFloat = 0.7
    private static let bannerAnimationInitialSpringVelocity : CGFloat = 1.0
    private static let bannerAnimationOffset : CGFloat = 200
    private static let bannerAnimationEndPoint : CGFloat = 0
    
    private let message: MMInAppMessage
    private let mode: Mode
    
    internal var dismissHandler: (() -> Void)?
    private let msgView: InAppMessageView
    private let inAppMessageClient: InAppMessageScriptClient
    
    /// Timer which schedules automatic dismiss of `msgView` if there is no user interaction
    private var mgsViewAutoDismissTimer: Timer?
    
    // MARK: - Fullscreen Constraints
    private var msgViewHeightToSafeArea: NSLayoutConstraint! // priority: 800
    
    // MARK: - Fullscreen and Popup Constraints
    private var msgViewCenterYToSafeArea: NSLayoutConstraint! // priority: 800
    /// The constraint which prevents `msgView` from going above the safe area.
    private var msgViewTopWithinSafeArea: NSLayoutConstraint! // priority: 800
    /// The constraint which prevents `msgView` from going below the safe area.
    private var msgViewBottomWithinSafeArea: NSLayoutConstraint! // priority: 800
    
    // MARK: - Banner Constraints
    /// The constraint which snaps the `msgView` to the top edge of the safe area
    private var msgViewToTop: NSLayoutConstraint! // priority: 800
    /// The constraint which snaps the `msgView` to the bottom edge of the safe area.
    private var msgViewToBottom: NSLayoutConstraint! // priority: 800
    
    // MARK: -
    /// The constraint which defines specific height of `msgView`.
    private var msgViewHeight: NSLayoutConstraint! // priority 700
    
    /// Constraints which need to be deactivated in order to position the banner properly before the animation, and then activated to animate the banner towards
    /// its destination.
    private var msgViewTopMargin: NSLayoutConstraint! // priority 1000
    private var msgViewBottomMargin: NSLayoutConstraint! // priority 1000
    
    // MARK: - Init
    init(message: MMInAppMessage, webViewWithHeight: WebViewWithHeight?, options: Options = Options.makeDefault()) {
        self.message = message
        
        if let webViewWithHeight {
            msgView = InAppMessageView(webView: webViewWithHeight.webView)
            mode = .preloadedWebViewWithHeightProvided(webViewWithHeight.height)
        } else {
            msgView = InAppMessageView(webView: WKWebView())
            mode = .fromScratch
        }
        
        // stops StatusBar from pushing webView's content down
        msgView.webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        msgView.cornerRadius = CGFloat(options.cornerRadius)
        inAppMessageClient = InAppMessageScriptClient(webView: msgView.webView)
        
        super.init(nibName: WebInteractiveMessageAlertController.nibName, bundle: MobileMessaging.resourceBundle)
        
        modalPresentationStyle = UIModalPresentationStyle.overFullScreen
        modalTransitionStyle = UIModalTransitionStyle.crossDissolve
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
        
        initializeWebViewMessageHandlers()
        configureMsgViewConstraints()
        
        switch mode {
        case .preloadedWebViewWithHeightProvided(let height):
            msgViewHeight.constant = height
        case .fromScratch:
            msgView.webView.navigationDelegate = self
            msgView.webView.load(URLRequest(url: message.url))
        }
        
        if message.type == .banner {
            msgView.webView.scrollView.isScrollEnabled = false
            msgView.webView.scrollView.bounces = false
            mgsViewAutoDismissTimer = Timer.scheduledTimer(
                timeInterval: WebInteractiveMessageAlertController.bannerAutoDismissDuration,
                target: self,
                selector: #selector(close),
                userInfo: nil,
                repeats: false)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if message.type == .banner {
            self.view.layoutIfNeeded()
            
            if message.position == .top {
                msgViewToTop.constant = WebInteractiveMessageAlertController.bannerAnimationEndPoint
            } else {
                msgViewToBottom.constant = WebInteractiveMessageAlertController.bannerAnimationEndPoint
            }
            
            msgViewTopMargin.isActive = true
            msgViewBottomMargin.isActive = true
            
            UIView.animate(
                withDuration: WebInteractiveMessageAlertController.bannerAnimationDuration,
                delay: WebInteractiveMessageAlertController.bannerAnimationDelayDuration,
                usingSpringWithDamping: WebInteractiveMessageAlertController.bannerAnimationUsingSpringWithDamping,
                initialSpringVelocity: WebInteractiveMessageAlertController.bannerAnimationInitialSpringVelocity,
                options: [.curveLinear, .allowUserInteraction],
                animations: {
                    self.view.layoutIfNeeded()
                })
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        configureMsgViewConstraints()
    }
    
    // MARK: - Actions
    @IBAction func onBackgroundTap(_ sender: UITapGestureRecognizer) {
        close()
    }
    
    // MARK: - Static Utils
    
    private static func setPriority(_ priority: Float, toConstraints constraints: [NSLayoutConstraint]) {
        for constraint in constraints {
            constraint.priority = UILayoutPriority(priority)
        }
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        inAppMessageClient.readBodyHeight { [self] height, error in
            guard let height else { return }
            msgViewHeight.constant = height
        }
    }
    
    // MARK: - Private
    /// Sets active state for all constraints.
    private static func setActiveState(_ active: Bool, toConstraints constraints: [NSLayoutConstraint]) {
        for constraint in constraints {
            constraint.isActive = active
        }
    }
    
    private func initializeWebViewMessageHandlers() {
        inAppMessageClient.onInAppMessageClosed() { [weak self] _ in self?.close() }
        
        if message.type == .popup {
            inAppMessageClient.onHeightChanged() { [weak self] message in
                if let height = (message.body as? NSNumber)?.doubleValue, let self {
                    let heightPts = height * self.view.contentScaleFactor
                    self.msgViewHeight.constant = heightPts
                }
            }
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
        
        /// Set to 200 so it covers animation for banner (banner itself will never have height more than 100)  when it slides from top/bottom
        msgViewToTop = msgView.topAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.topAnchor,
            constant: CGFloat(-1 * WebInteractiveMessageAlertController.bannerAnimationOffset))
        msgViewToBottom = msgView.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor,
            constant: CGFloat(WebInteractiveMessageAlertController.bannerAnimationOffset))
        WebInteractiveMessageAlertController.setPriority(800, toConstraints: [msgViewHeightToSafeArea,
                                                                              msgViewCenterYToSafeArea,
                                                                              msgViewTopWithinSafeArea,
                                                                              msgViewBottomWithinSafeArea,
                                                                              msgViewToTop,
                                                                              msgViewToBottom])
        
        msgViewHeight = msgView.heightAnchor.constraint(
            equalToConstant: WebInteractiveMessageAlertController.initialBannerHeight)
        WebInteractiveMessageAlertController.setPriority(700, toConstraints: [msgViewHeight])
        
        msgViewTopMargin = msgView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor,
                                                        constant: WebInteractiveMessageAlertController.margin)
        msgViewBottomMargin = msgView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor,
                                                              constant: -WebInteractiveMessageAlertController.margin)
        
        if message.type != .banner {
            msgViewTopMargin.isActive = true
            msgViewBottomMargin.isActive = true
            // Otherwise banner will activate them through the animation.
        }
    }
    
    private func configureMsgViewConstraints() {
        NSLayoutConstraint.deactivate([
            msgViewHeightToSafeArea,
            msgViewCenterYToSafeArea,
            msgViewTopWithinSafeArea,
            msgViewBottomWithinSafeArea,
            msgViewHeight,
            msgViewToTop,
            msgViewToBottom
        ])
        
        switch (message.type) {
        case .banner:
            msgViewHeight.isActive = true
            
            switch message.position {
            case .top:
                msgViewToTop.isActive = true
            case .bottom:
                msgViewToBottom.isActive = true
            case .none:
                break
            }
        case .fullscreen:
            msgViewHeightToSafeArea.isActive = true
            fallthrough
        case .popup:
            msgViewCenterYToSafeArea.isActive = true
            msgViewTopWithinSafeArea.isActive = true
            msgViewBottomWithinSafeArea.isActive = true
        }
    }
    
    /// Dismisses the controller and calls the dismiss handler if it exists.
    @objc
    private func close() {
        if message.type == .banner {
            mgsViewAutoDismissTimer?.invalidate()
            let direction = message.position == .top ? -1 : 1
            let transformDirection = CGAffineTransformMakeTranslation(0, WebInteractiveMessageAlertController.bannerAnimationOffset * CGFloat(direction))
            
            UIView.animate(
                withDuration: WebInteractiveMessageAlertController.bannerAnimationDuration,
                delay: WebInteractiveMessageAlertController.bannerAnimationDelayDuration,
                usingSpringWithDamping: WebInteractiveMessageAlertController.bannerAnimationUsingSpringWithDamping,
                initialSpringVelocity: WebInteractiveMessageAlertController.bannerAnimationInitialSpringVelocity,
                options: [.curveLinear, .allowUserInteraction],
                animations: {
                    self.msgView.transform = transformDirection
                }) { [weak self] _ in
                    self?.dismiss(animated: true) { [weak self] in self?.dismissHandler?() }
                }
        } else {
            dismiss(animated: true) { [weak self] in self?.dismissHandler?() }
        }
    }
}

fileprivate class InAppMessageView: UIView {
    private static let shadowOpacity: Float = 0.7
    private static let shadowRadius: CGFloat = 4.0
    private static let shadowOffset = CGSize(width: 3, height: 3)
    
    let webView: WKWebView
    
    var cornerRadius: CGFloat {
        get {
            layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            webView.layer.cornerRadius = newValue
        }
    }
    
    fileprivate init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: webView.frame)
        addSubview(webView)
        
        // Important for constraints
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            webView.heightAnchor.constraint(equalTo: heightAnchor),
            webView.widthAnchor.constraint(equalTo: widthAnchor),
            webView.centerXAnchor.constraint(equalTo: centerXAnchor),
            webView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Important for corner radius
        webView.clipsToBounds = true
        
        // Shadow definition
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = InAppMessageView.shadowOffset
        layer.shadowOpacity = InAppMessageView.shadowOpacity
        layer.shadowRadius = InAppMessageView.shadowRadius
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
