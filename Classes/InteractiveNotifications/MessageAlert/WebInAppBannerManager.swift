import Foundation
import UIKit
import WebKit


class WebInAppBannerManager: NSObject, WKNavigationDelegate {
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
    private let msgView: WebInAppMessageView
    private let inAppMessageClient: InAppMessageScriptClient
    
    /// Timer which schedules automatic dismiss of `msgView` if there is no user interaction
    private var mgsViewAutoDismissTimer: Timer?
    
    /// The constraint which snaps the `msgView` to the top edge of the safe area
    private var msgViewToTop: NSLayoutConstraint! // priority: 800
    /// The constraint which snaps the `msgView` to the bottom edge of the safe area.
    private var msgViewToBottom: NSLayoutConstraint! // priority: 800
    
    /// The constraint which defines specific height of `msgView`.
    private var msgViewHeight: NSLayoutConstraint! // priority 700
    
    /// Constraints which need to be deactivated in order to position the banner properly before the animation, and then activated to animate the banner towards
    /// its destination.
    private var msgViewTopMargin: NSLayoutConstraint! // priority 1000
    private var msgViewBottomMargin: NSLayoutConstraint! // priority 1000
    
    /// Our main "view" which will hold the banner and show our msgView
    private var keyWindow: UIWindow!
    
    // MARK: - Init
    init(message: MMInAppMessage, webViewWithHeight: WebViewWithHeight?, options: Options = Options.makeDefault()) {
        self.message = message
        
        if let webViewWithHeight {
            msgView = WebInAppMessageView(webView: webViewWithHeight.webView)
            mode = .preloadedWebViewWithHeightProvided(webViewWithHeight.height)
        } else {
            msgView = WebInAppMessageView(webView: WKWebView())
            mode = .fromScratch
        }
        
        // stops StatusBar from pushing webView's content down
        msgView.webView.scrollView.contentInsetAdjustmentBehavior = .never
        msgView.cornerRadius = CGFloat(options.cornerRadius)
        inAppMessageClient = InAppMessageScriptClient(webView: msgView.webView)
        
    }
    
    func startPresenting() {
        if #available(iOS 13.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
                addViewToKeyWindow(keyWindow)
            }
        } else {
            if let keyWindow = UIApplication.shared.keyWindow {
                addViewToKeyWindow(keyWindow)
            }
        }
    }
    
    func viewDidSetup() {
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
        
        msgView.webView.scrollView.isScrollEnabled = false
        msgView.webView.scrollView.bounces = false
        mgsViewAutoDismissTimer = Timer.scheduledTimer(
            timeInterval: WebInAppBannerManager.bannerAutoDismissDuration,
            target: self,
            selector: #selector(dismiss),
            userInfo: nil,
            repeats: false)
    }
    
    func viewWillShow() {
        if message.position == .top {
            msgViewToTop.constant = WebInAppBannerManager.bannerAnimationEndPoint
        } else {
            msgViewToBottom.constant = WebInAppBannerManager.bannerAnimationEndPoint
        }
        
        msgViewTopMargin.isActive = true
        msgViewBottomMargin.isActive = true
        
        UIView.animate(
            withDuration: WebInAppBannerManager.bannerAnimationDuration,
            delay: WebInAppBannerManager.bannerAnimationDelayDuration,
            usingSpringWithDamping: WebInAppBannerManager.bannerAnimationUsingSpringWithDamping,
            initialSpringVelocity: WebInAppBannerManager.bannerAnimationInitialSpringVelocity,
            options: [.curveLinear, .allowUserInteraction],
            animations: { [weak self] in
                self?.keyWindow.layoutIfNeeded()
            })
    }
    
    private func addViewToKeyWindow(_ localKeyWindow: UIWindow) {
        keyWindow = localKeyWindow
        keyWindow.addSubview(msgView)
        keyWindow.layoutIfNeeded()
        viewDidSetup()
        viewWillShow()
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
        inAppMessageClient.onInAppMessageClosed() { [weak self] _ in self?.dismiss() }
    }
    
    /// Initializes constraints which are static in a sense that they hold forever and never need to be adjusted again.
    private func initializeStaticConstraints() {
        let constraints = [
            // Constraint which centers the message view horizontally.
            msgView.centerXAnchor.constraint(equalTo: keyWindow.safeAreaLayoutGuide.centerXAnchor),
            
            // Constraint which defines specific width of `msgView`.
            msgView.widthAnchor.constraint(equalToConstant: calculateInAppMessageWidth(
                superFrame: keyWindow.frame,
                margin: WebInAppBannerManager.margin))
        ]
        WebInAppBannerManager.setPriority(800, toConstraints: constraints)
        NSLayoutConstraint.activate(constraints)
        
        let horizontalMarginConstraints = [
            msgView.leftAnchor.constraint(greaterThanOrEqualTo: keyWindow.leftAnchor,
                                          constant: WebInAppBannerManager.margin),
            msgView.rightAnchor.constraint(lessThanOrEqualTo: keyWindow.rightAnchor,
                                           constant: -WebInAppBannerManager.margin),
        ]
        
        WebInAppBannerManager.setPriority(1000, toConstraints: horizontalMarginConstraints)
        NSLayoutConstraint.activate(horizontalMarginConstraints)
    }
    
    /// Initializes constraints which need to be customized dynamically so references to them are stored as members.
    private func initializeDynamicConstraints() {
        /// Set to 200 so it covers animation for banner (banner itself will never have height more than 100)  when it slides from top/bottom
        msgViewToTop = msgView.topAnchor.constraint(
            equalTo: keyWindow.safeAreaLayoutGuide.topAnchor,
            constant: CGFloat(-1 * WebInAppBannerManager.bannerAnimationOffset))
        msgViewToBottom = msgView.bottomAnchor.constraint(
            equalTo: keyWindow.safeAreaLayoutGuide.bottomAnchor,
            constant: CGFloat(WebInAppBannerManager.bannerAnimationOffset))
        WebInAppBannerManager.setPriority(800, toConstraints:
                                            [msgViewToTop,
                                             msgViewToBottom]
        )
        
        msgViewHeight = msgView.heightAnchor.constraint(
            equalToConstant: WebInAppBannerManager.initialBannerHeight)
        WebInAppBannerManager.setPriority(700, toConstraints: [msgViewHeight])
        
        msgViewTopMargin = msgView.topAnchor.constraint(greaterThanOrEqualTo: keyWindow.topAnchor,
                                                        constant: WebInAppBannerManager.margin)
        msgViewBottomMargin = msgView.bottomAnchor.constraint(lessThanOrEqualTo: keyWindow.bottomAnchor,
                                                              constant: -WebInAppBannerManager.margin)
    }
    
    private func configureMsgViewConstraints() {
        NSLayoutConstraint.deactivate([
            msgViewHeight,
            msgViewToTop,
            msgViewToBottom
        ])
        msgViewHeight.isActive = true
        
        switch message.position {
        case .top:
            msgViewToTop.isActive = true
        case .bottom:
            msgViewToBottom.isActive = true
        case .none:
            break
        }
    }
    
    /// Dismisses the banner and calls the dismiss handler if it exists.
    @objc
    func dismiss() {
        mgsViewAutoDismissTimer?.invalidate()
        let direction = message.position == .top ? -1 : 1
        let transformDirection = CGAffineTransformMakeTranslation(0, WebInAppBannerManager.bannerAnimationOffset * CGFloat(direction))
        
        UIView.animate(
            withDuration: WebInAppBannerManager.bannerAnimationDuration,
            delay: WebInAppBannerManager.bannerAnimationDelayDuration,
            usingSpringWithDamping: WebInAppBannerManager.bannerAnimationUsingSpringWithDamping,
            initialSpringVelocity: WebInAppBannerManager.bannerAnimationInitialSpringVelocity,
            options: [.curveLinear, .allowUserInteraction],
            animations: {
                self.keyWindow.layoutIfNeeded()
                self.msgView.transform = transformDirection
            }) { _ in
                self.msgView.removeFromSuperview()
                self.dismissHandler?()
            }
    }
}
