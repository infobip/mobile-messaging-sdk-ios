import Foundation
import WebKit

/// Shows a new-style in-app message using a webView.
class WebInteractiveMessageAlertController: UIViewController, InteractiveMessageAlertController {
    static let nibName = "WebInteractiveMessageAlertController"
    
    static let webViewWidthInLandscape = 300
    
    /// The action which happens when message is dismissed due to interaction with its html content.
    static let closeAction = "close"
    /// The action which happens when height of the message's html content changes.
    static let heightChangedAction = "heightChanged"
    
    private let message: MMWebInAppMessage
    
    /// The measure in points which tells how much of html content height will be cut off because `webView` ends up being too short for some reason.
    private var webViewHeightInset: Double {
        return Double(view.contentScaleFactor) * 4
    }
    
    /// The flag which controls whether the message will cover the whole area from edge to edge.
    /// - Attention: This is now hardcoded because it's usage through API is yet to be decided.
    private let exclusiveFullscreen = false
    
    internal var dismissHandler: (() -> Void)?
    
    @IBOutlet weak var webView: WKWebView!
    
    // MARK: - Exclusive fullscreen constraints
    // These constaints stretch the message to cover the whole screen beyond the safe area.
    @IBOutlet var webViewCenterXToSuper: NSLayoutConstraint! // priority: 900
    @IBOutlet var webViewCenterYToSuper: NSLayoutConstraint! // priority: 900
    @IBOutlet var webViewHeightToSuper: NSLayoutConstraint! // priority: 900
    @IBOutlet var webViewWidthToSuper: NSLayoutConstraint! // priority: 900
    
    // MARK: - Non-exclusive fullscreen constraints
    // These constaints stretch the message to cover the whole safe area. This effectively means they will leave some
    // margins at the edges depending on the device.
    @IBOutlet var webViewCenterXToSafeArea: NSLayoutConstraint! // priority: 800
    @IBOutlet var webViewCenterYToSafeArea: NSLayoutConstraint! // priority: 800
    @IBOutlet var webViewWidthToSafeArea: NSLayoutConstraint! // priority: 800
    @IBOutlet var webViewHeightToSafeArea: NSLayoutConstraint! // priority: 800
    
    /// The constraint which prevents `webView` from going above the safe area.
    @IBOutlet var webViewTopWithinSafeArea: NSLayoutConstraint! // priority: 800
    /// The constraint which prevents `webView` from going below the safe area.
    @IBOutlet var webViewBottomWithinSafeArea: NSLayoutConstraint! // priority: 800
    
    /// The constraint which defines specific height of `webView`.
    @IBOutlet var webViewHeight: NSLayoutConstraint! // priority 700
    /// The constraint which defines specific width of `webView` in landscape.
    @IBOutlet var webViewWidthLandscape: NSLayoutConstraint! // priority 700
    
    /// The constraint which snaps the `webView` to the top edge of the safe area
    @IBOutlet var webViewToTop: NSLayoutConstraint! // priority: 600
    /// The constraint which snaps the `webView` to the bottom edge of the safe area.
    @IBOutlet var webViewToBottom: NSLayoutConstraint! // priority: 500
    
    // MARK: -
    init(message: MMWebInAppMessage) {
        self.message = message
        super.init(nibName: WebInteractiveMessageAlertController.nibName, bundle: MobileMessaging.resourceBundle)
        self.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
        self.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        initializeWebView()
        configureConstraints()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let request = URLRequest(url: message.url)
        webView.load(request)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        configureConstraints()
        setupWebViewCorners()
    }
    
    @IBAction func onBackgrundTap(_ sender: UITapGestureRecognizer) {
        close()
    }
    
    /// Dismisses the controller and calls the dismiss handler if it exists.
    public func close() {
        dismiss(animated: true) { [weak self] in self?.dismissHandler?() }
    }
    
    private func initializeWebView() {
        webView.onMessage(WebInteractiveMessageAlertController.closeAction) { [weak self] _ in self?.close() }
        webView.onMessage(WebInteractiveMessageAlertController.heightChangedAction) { [weak self] message in
            if let height = (message.body as? NSNumber)?.doubleValue, let self {
                let heightPts = height * self.view.contentScaleFactor
                self.webViewHeight.constant = heightPts + self.webViewHeightInset
            }
        }
        webView.layer.cornerRadius = 16
        setupWebViewCorners()
    }
    
    private func setupWebViewCorners() {
        if message.type == .popup && UIDevice.current.orientation.isLandscape {
            webView.layer.maskedCorners = [.bottomLeft, .bottomRight]
        } else {
            webView.layer.maskedCorners = [.topLeft, .topRight, .bottomLeft, .bottomRight]
        }
    }
    
    // MARK: - Constraints configuration
    private func configureConstraints() {
        guard !exclusiveFullscreen else {
            /// In the case of exclusive screen we can just turn on all constraints to the super-view and ignore the rest because constraints governing exclusive
            /// fullscreen have the highest priority.
            setWebViewToSuperConstraintsActive(active: true)
            return
        }
        
        setWebViewToSuperConstraintsActive(active: false)
        
        /// First stretch the `webView` to cover the whole safe area.
        webViewCenterXToSafeArea.isActive = true
        webViewCenterYToSafeArea.isActive = true
        webViewHeightToSafeArea.isActive = true
        webViewWidthToSafeArea.isActive = true
        
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
    }
   
    private func setWebViewToSuperConstraintsActive(active: Bool) {
        webViewCenterXToSuper.isActive = active
        webViewCenterYToSuper.isActive = active
        webViewHeightToSuper.isActive = active
        webViewWidthToSuper.isActive = active
    }
}

private extension WKWebView {
    /// Reads the height of the html body asynchronously.
    func readBodyHeight(onFinish handler: @escaping (CGFloat?) -> Void) {
        evaluateJavaScript("document.body.scrollHeight") { height, _ in handler(height as? CGFloat) }
    }
    
    /// Registers an action which will handle messages sent by javascript.
    func onMessage(_ name: String, execute action: @escaping (WKScriptMessage) -> Void) {
        let handler = MessageHandler(action: action)
        self.configuration.userContentController.add(handler, name: name)
    }
    
    /// A generic message handler which simplifies handling of javascript messages by using only closures.
    private class MessageHandler: NSObject, WKScriptMessageHandler {
        /// An action which will handle messages sent by javascript.
        private var action: (WKScriptMessage) -> Void
        
        init(action: @escaping (WKScriptMessage) -> Void) {
            self.action = action
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            action(message)
        }
    }
}

extension CACornerMask {
    static let bottomLeft = CACornerMask.layerMinXMinYCorner
    static let bottomRight = CACornerMask.layerMaxXMinYCorner
    static let topLeft = CACornerMask.layerMinXMaxYCorner
    static let topRight = CACornerMask.layerMaxXMaxYCorner
}
