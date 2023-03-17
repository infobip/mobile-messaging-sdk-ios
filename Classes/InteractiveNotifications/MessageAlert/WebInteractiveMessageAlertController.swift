import Foundation
import WebKit

/// Shows a new-style in-app message using a webView.
class WebInteractiveMessageAlertController: UIViewController, InteractiveMessageAlertController {
    struct Options {
        static func makeDefault () -> Self {
            Options(cornerRadius: MMInteractiveMessageAlertSettings.cornerRadius)
        }
        
        let cornerRadius: Float
    }
    
    private static let nibName = "WebInteractiveMessageAlertController"
    private static let bannerHeight = 100.0
    private static let webViewWidthInLandscape = 300.0
    private static let horizontalMargin = 8.0
    
    private let message: MMInAppMessage
    
    /// The measure in points which tells how much of html content height will be cut off because `webView` ends up being too short for some reason.
    private var webViewHeightInset: Double {
        return Double(view.contentScaleFactor) * 4
    }
    
    /// The flag which controls whether the message will cover the whole area from edge to edge.
    /// - Attention: This is now hardcoded because it's usage through API is yet to be decided.
    private let exclusiveFullscreen = false
    
    internal var dismissHandler: (() -> Void)?
    
    private let webView: WKWebView
    private let inAppMessageClient: InAppMessageScriptClient
    
    // MARK: - Exclusive fullscreen constraints
    // These constaints stretch the message to cover the whole screen beyond the safe area.
    private var webViewCenterXToSuper: NSLayoutConstraint! // priority: 900
    private var webViewCenterYToSuper: NSLayoutConstraint! // priority: 900
    private var webViewHeightToSuper: NSLayoutConstraint! // priority: 900
    private var webViewWidthToSuper: NSLayoutConstraint! // priority: 900
    
    // MARK: - Non-exclusive fullscreen constraints
    // These constaints stretch the message to cover the whole safe area. This effectively means they will leave some
    // margins at the edges depending on the device.
    private var webViewCenterXToSafeArea: NSLayoutConstraint! // priority: 800
    private var webViewCenterYToSafeArea: NSLayoutConstraint! // priority: 800
    private var webViewWidthToSafeArea: NSLayoutConstraint! // priority: 800
    private var webViewHeightToSafeArea: NSLayoutConstraint! // priority: 800
    
    /// The constraint which prevents `webView` from going above the safe area.
    private var webViewTopWithinSafeArea: NSLayoutConstraint! // priority: 800
    /// The constraint which prevents `webView` from going below the safe area.
    private var webViewBottomWithinSafeArea: NSLayoutConstraint! // priority: 800
    
    // MARK: -
    /// The constraint which defines specific height of `webView`.
    private var webViewHeight: NSLayoutConstraint! // priority 700
    /// The constraint which defines specific width of `webView` in landscape.
    private var webViewWidthLandscape: NSLayoutConstraint! // priority 700
    
    /// The constraint which snaps the `webView` to the top edge of the safe area
    private var webViewToTop: NSLayoutConstraint! // priority: 600
    /// The constraint which snaps the `webView` to the bottom edge of the safe area.
    private var webViewToBottom: NSLayoutConstraint! // priority: 500
    
    // MARK: - Init
    init(message: MMInAppMessage, webView: WKWebView, options: Options = Options.makeDefault()) {
        self.message = message
        self.webView = webView
        self.inAppMessageClient = InAppMessageScriptClient(webView: webView)
        
        super.init(nibName: WebInteractiveMessageAlertController.nibName, bundle: MobileMessaging.resourceBundle)
        
        self.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
        self.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Controller Lifecycle
    override func viewDidLoad() {
        self.view.addSubview(webView)
        initializeWebViewConstraints()
        
        webView.layer.cornerRadius = 16
        webView.clipsToBounds = true
        initializeWebViewMessageHandlers()
        configureWebViewCorners()
        configureWebViewConstraints()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        configureWebViewCorners()
        configureWebViewConstraints()
    }
    
    // MARK: - Actions
    @IBAction func onBackgroundTap(_ sender: UITapGestureRecognizer) {
        close()
    }
    
    // MARK: - Static Utils
    
    private static func setPriority(_ priority: Float, toConstraints constraints: NSLayoutConstraint...) {
        for constraint in constraints {
            constraint.priority = UILayoutPriority(priority)
        }
    }
    
    // MARK: - Private
    
    /// Sets active state for all constraints.
    private static func setActiveState(_ active: Bool, toConstraints constraints: NSLayoutConstraint...) {
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
                    self.webViewHeight.constant = heightPts + self.webViewHeightInset
                }
            }
        }
    }
    
    private func configureWebViewCorners() {
        if message.type == .popup && UIDevice.current.orientation.isLandscape {
            webView.layer.maskedCorners = [.bottomLeft, .bottomRight]
        } else {
            webView.layer.maskedCorners = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        }
    }
    
    private func initializeWebViewConstraints() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        webViewCenterXToSuper = webView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        webViewCenterYToSuper = webView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        webViewWidthToSuper = webView.widthAnchor.constraint(equalTo: view.widthAnchor)
        webViewHeightToSuper = webView.heightAnchor.constraint(equalTo: view.heightAnchor)
        WebInteractiveMessageAlertController.setPriority(900, toConstraints: webViewCenterXToSuper,
                                                         webViewCenterYToSuper,
                                                         webViewWidthToSuper,
                                                         webViewHeightToSuper)
        
        webViewCenterXToSafeArea = webView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor)
        webViewCenterYToSafeArea = webView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        webViewWidthToSafeArea = webView.widthAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.widthAnchor,
            constant: -WebInteractiveMessageAlertController.horizontalMargin * 2)
        webViewHeightToSafeArea = webView.heightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.heightAnchor)
        webViewTopWithinSafeArea = webView.topAnchor.constraint(
            greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor)
        webViewBottomWithinSafeArea = webView.topAnchor.constraint(
            lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor)
        WebInteractiveMessageAlertController.setPriority(800, toConstraints: webViewCenterXToSafeArea,
                                                         webViewCenterYToSafeArea,
                                                         webViewWidthToSafeArea,
                                                         webViewHeightToSafeArea,
                                                         webViewTopWithinSafeArea,
                                                         webViewBottomWithinSafeArea)
        
        webViewHeight = webView.heightAnchor.constraint(
            equalToConstant: WebInteractiveMessageAlertController.bannerHeight)
        webViewWidthLandscape = webView.widthAnchor.constraint(
            equalToConstant: WebInteractiveMessageAlertController.webViewWidthInLandscape)
        WebInteractiveMessageAlertController.setPriority(700, toConstraints: webViewHeight, webViewWidthLandscape)
        
        webViewToTop = webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        WebInteractiveMessageAlertController.setPriority(600, toConstraints: webViewToTop)
        
        webViewToBottom = webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        WebInteractiveMessageAlertController.setPriority(500, toConstraints: webViewToBottom)
        
        NSLayoutConstraint.activate([
            webViewCenterXToSuper,
            webViewCenterYToSuper,
            webViewHeightToSuper,
            webViewWidthToSuper,
            webViewCenterXToSafeArea,
            webViewCenterYToSafeArea,
            webViewWidthToSafeArea,
            webViewHeightToSafeArea,
            webViewTopWithinSafeArea,
            webViewBottomWithinSafeArea,
            webViewHeight,
            webViewWidthLandscape,
            webViewToTop,
            webViewToBottom
        ])
    }
    
    private func configureWebViewConstraints() {
        guard !exclusiveFullscreen else {
            /// In the case of exclusive screen we can just turn on all constraints to the super-view and ignore the rest because constraints governing exclusive
            /// fullscreen have the highest priority.
            setWebViewToSuperConstraintsActive(active: true)
            return
        }
        
        setWebViewToSuperConstraintsActive(active: false)
        
        /// First stretch the `webView` to cover the whole safe area.
        WebInteractiveMessageAlertController.setActiveState(true, toConstraints: webViewCenterXToSafeArea,
                                                            webViewCenterYToSafeArea,
                                                            webViewHeightToSafeArea,
                                                            webViewWidthToSafeArea)
        
        let isLandscape = UIDevice.current.orientation.isLandscape
        
        /// Setup `webView` height and width.
        switch (message.type) {
        case .fullscreen:
            /// It's already as it should be.
            break
        case .popup, .banner:
            /// Remove constraint which stretches `webView` vertically so it can be set dynamically to specific values according to the content height.
            webViewHeightToSafeArea.isActive = false
            
            if isLandscape {
                /// Remove constraint which stretches `webView` horizontally so it can be set dynamically to
                /// specific value by `webViewWidthLandscape` constraint.
                webViewWidthToSafeArea.isActive = false
            }
        }
        
        /// Setup `webView` vertical position.
        switch (message.type, message.position, isLandscape) {
        case (.fullscreen, _, _):
            /// It's already as it should be.
            break
        case (.banner, .top, _), (.banner, .none, _):
            webViewCenterYToSafeArea.isActive = false
            webViewToTop.isActive = true
        case (.banner, .bottom, _), (.popup, _, true):
            webViewCenterYToSafeArea.isActive = false
            webViewToTop.isActive = false
        case (.popup, _, false):
            webViewCenterYToSafeArea.isActive = true
        }
        
        /// Sets active state for all `webView` constraints to super-view.
        func setWebViewToSuperConstraintsActive(active: Bool) {
            WebInteractiveMessageAlertController.setActiveState(active, toConstraints: webViewCenterXToSuper,
                                                                webViewCenterYToSuper,
                                                                webViewHeightToSuper,
                                                                webViewWidthToSuper)
        }
    }
    
    /// Dismisses the controller and calls the dismiss handler if it exists.
    private func close() {
        dismiss(animated: true) { [weak self] in self?.dismissHandler?() }
    }
}

private extension WKWebView {
    /// Reads the height of the html body asynchronously.
    func readBodyHeight(onFinish handler: @escaping (CGFloat?) -> Void) {
        evaluateJavaScript("document.body.scrollHeight") { height, _ in handler(height as? CGFloat) }
    }
}

extension CACornerMask {
    static let bottomLeft = CACornerMask.layerMinXMinYCorner
    static let bottomRight = CACornerMask.layerMaxXMinYCorner
    static let topLeft = CACornerMask.layerMinXMaxYCorner
    static let topRight = CACornerMask.layerMaxXMaxYCorner
}
