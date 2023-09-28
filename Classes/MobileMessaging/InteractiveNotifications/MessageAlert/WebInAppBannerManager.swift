import Foundation
import UIKit
import WebKit

class WebInAppBannerManager: NSObject, NamedLogger, WKNavigationDelegate, UserInteractionEventListener {
    struct Options {
        static func makeDefault () -> Self {
            Options(cornerRadius: MMInteractiveMessageAlertSettings.cornerRadius)
        }
        
        let cornerRadius: Float
    }
    
    private static let initialBannerHeight = 100.0
    private static let bannerAutoDismissDuration : TimeInterval = 5.0
    private static let bannerAnimationDuration : TimeInterval = 0.5
    private static let bannerAnimationDelayDuration : TimeInterval = 0.0
    private static let bannerAnimationUsingSpringWithDamping : CGFloat = 0.7
    private static let bannerAnimationInitialSpringVelocity : CGFloat = 1.0
    private static let bannerAnimationOffset : CGFloat = 200
    private static let bannerAnimationEndPoint : CGFloat = 0
    
    private let message: MMInAppMessage
    weak var delegate: InAppMessageDelegate?
    
    private let msgView: WebInAppMessageView
    private let preloadedMsgHeight: CGFloat
    
    /// Timer which schedules automatic dismissal of `msgView` if there is no user interaction
    private var mgsViewAutoDismissTimer: Timer?
    
    /// The constraint which defines specific height of `msgView`.
    private var msgViewHeight: NSLayoutConstraint! // priority 500
    
    /// The constraint which puts `msgView`outside of the screen (above or below).
    private var msgViewStartPosition: NSLayoutConstraint! // priority: 400
    /// Constraint which needs to be activated in order to position the `msgView` inside the safe area.
    private var msgViewEndPosition: NSLayoutConstraint! // priority 500
    
    /// Our main "view" which will show `msgView`.
    private var container: UIView!
    
    private let scriptEventRecipient: ScriptEventRecipient
    private let scriptMethodInvoker: ScriptMethodInvoker

    init(
        message: MMInAppMessage,
        webViewWithHeight: WebViewWithHeight,
        options: Options = Options.makeDefault()
    ) {
        self.message = message
        
        msgView = WebInAppMessageView(webView: webViewWithHeight.webView)
        preloadedMsgHeight = webViewWithHeight.height
        
        // Stop StatusBar from pushing webView's content down.
        msgView.webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Disable unvanted gestures.
        msgView.webView.scrollView.isScrollEnabled = false
        msgView.webView.scrollView.bounces = false
        
        msgView.cornerRadius = CGFloat(options.cornerRadius)
        msgView.translatesAutoresizingMaskIntoConstraints = false
        
        scriptEventRecipient = ScriptEventRecipient(webView: msgView.webView)
        scriptMethodInvoker = ScriptMethodInvoker(webView: msgView.webView)
        
        super.init()
        
        scriptEventRecipient.listener = self
    }
    
    func startPresenting() {
        self.container = UIApplication.usableWindow
        guard self.container != nil else { return }
        
        container.addSubview(msgView)
        
        initializeStaticConstraints()
        initializeDynamicConstraints()
        
        setupDismissTimer()
        
        container.layoutIfNeeded()
        
        animateMsgViewIntoScreen()
    }

    @objc
    func dismissAndNotifyDelegate() {
        dismiss { self.delegate?.inAppMessageDidDismiss() }
    }
    
    func dismiss(_ action: ( () -> Void)? = nil) {
        cleanupDismissTimer()
        animateMsgViewOutOfScreen() {
            self.msgView.removeFromSuperview()
            action?()
        }
    }
    
    // MARK: - UserInteractionEventListener
    func scriptEventRecipientDidDetectOpenBrowser(withUrl url: String) {
        scriptEventRecipient.listener = nil
        dismiss {
            self.delegate?.inAppMessageDidReceiveAction(MMNotificationAction.DefaultActionId,
                                                        internalDataKey: Consts.InternalDataKeys.browserUrl,
                                                        url: url)
        }
    }
    
    func scriptEventRecipientDidDetectOpenWebView(withUrl url: String) {
        scriptEventRecipient.listener = nil
        dismiss {
            self.delegate?.inAppMessageDidReceiveAction(MMNotificationAction.DefaultActionId,
                                                        internalDataKey: Consts.InternalDataKeys.webViewUrl,
                                                        url: url)
        }
    }
    
    func scriptEventRecipientDidDetectOpenAppPage(withDeeplink deeplink: String) {
        scriptEventRecipient.listener = nil
        dismiss {
            self.delegate?.inAppMessageDidReceiveAction(MMNotificationAction.DefaultActionId,
                                                        internalDataKey: Consts.InternalDataKeys.deeplink,
                                                        url: deeplink)
        }
    }
    
    func scriptEventRecipientDidDetectClose() {
        scriptEventRecipient.listener = nil
        dismiss { self.delegate?.inAppMessageDidClose() }
    }
    
    // MARK: - Constraint Initialization
    /// Initializes constraints which are static in a sense that they hold forever and never need to be adjusted again.
    private func initializeStaticConstraints() {
        let constraints = [
            // Constraint which centers the message view horizontally.
            msgView.centerXAnchor.constraint(equalTo: container.safeAreaLayoutGuide.centerXAnchor),
            
            // Constraint which defines specific width of `msgView`.
            msgView.widthAnchor.constraint(equalToConstant: container.frame.smallerDimension - inAppHorizontalMargin),
            
            msgView.leftAnchor.constraint(greaterThanOrEqualTo: container.leftAnchor, constant: inAppHorizontalMargin),
            msgView.rightAnchor.constraint(lessThanOrEqualTo: container.rightAnchor, constant: -inAppHorizontalMargin)
        ]
        constraints.setPriority(500)
        NSLayoutConstraint.activate(constraints)
    }
    
    /// Initializes constraints which need to be customized dynamically so references to them are stored as members.
    private func initializeDynamicConstraints() {
        msgViewHeight = msgView.heightAnchor.constraint(equalToConstant: preloadedMsgHeight)
        msgViewHeight.setPriority(500)
        
        switch message.position {
        case .top:
            // Start above the screen.
            msgViewStartPosition = msgView.bottomAnchor.constraint(equalTo: container.topAnchor)
            // End below the top edge of the safe area.
            msgViewEndPosition = msgView.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor)
        case .bottom:
            // Start below the screen.
            msgViewStartPosition = msgView.topAnchor.constraint(equalTo: container.bottomAnchor)
            // End above the bottom edge of the safe area.
            msgViewEndPosition = msgView.bottomAnchor.constraint(equalTo: container.safeAreaLayoutGuide.bottomAnchor)
        case .none:
            break
        }
        // Start position has lower priority so it can be overriden by the end position.
        msgViewStartPosition.setPriority(400)
        msgViewEndPosition.setPriority(500)
        NSLayoutConstraint.activate([msgViewHeight, msgViewStartPosition])
    }
    
    
    // MARK: - MsgView Animations
    private func animateMsgViewIntoScreen() {
        UIView.animate(
            withDuration: WebInAppBannerManager.bannerAnimationDuration,
            delay: WebInAppBannerManager.bannerAnimationDelayDuration,
            usingSpringWithDamping: WebInAppBannerManager.bannerAnimationUsingSpringWithDamping,
            initialSpringVelocity: WebInAppBannerManager.bannerAnimationInitialSpringVelocity,
            options: [.curveLinear, .allowUserInteraction],
            animations: { [weak self] in
                self?.msgViewEndPosition.isActive = true
                self?.container.layoutIfNeeded()
            })
    }
    
    private func animateMsgViewOutOfScreen(completion: ( () -> Void)? = nil) {
        let animations = {
            self.msgViewEndPosition.isActive = false
            self.container.layoutIfNeeded()
        }
        
        UIView.animate(
            withDuration: WebInAppBannerManager.bannerAnimationDuration,
            delay: WebInAppBannerManager.bannerAnimationDelayDuration,
            usingSpringWithDamping: WebInAppBannerManager.bannerAnimationUsingSpringWithDamping,
            initialSpringVelocity: WebInAppBannerManager.bannerAnimationInitialSpringVelocity,
            options: [.curveLinear, .allowUserInteraction],
            animations: animations) { _ in
                completion?()
            }
    }
    
    // MARK: - Dismiss Timer
    private func setupDismissTimer() {
        mgsViewAutoDismissTimer = Timer.scheduledTimer(
            timeInterval: WebInAppBannerManager.bannerAutoDismissDuration,
            target: self,
            selector: #selector(dismissAndNotifyDelegate),
            userInfo: nil,
            repeats: false)
    }
    
    private func cleanupDismissTimer() {
        mgsViewAutoDismissTimer?.invalidate()
    }
}

// MARK: - Utility Extensions
fileprivate extension UIApplication {
    /// Tries to find the first window which can be used to present the banner.
    static var usableWindow: UIWindow? {
        get {
            if #available(iOS 13.0, *) {
                return UIApplication.firstForegroundConnectedScene?.firstKeyWindow
            } else {
                return UIApplication.shared.keyWindow
            }
        }
    }
    
    @available(iOS 13.0, *)
    static var firstForegroundConnectedScene: UIWindowScene? {
        get {
            return UIApplication.shared.connectedScenes.first(
                where: { $0.activationState == .foregroundActive }
            ) as? UIWindowScene
        }
    }
}

@available(iOS 13.0, *)
fileprivate extension UIWindowScene {
    var firstKeyWindow: UIWindow? {
        get { return windows.first(where: { $0.isKeyWindow }) }
    }
}


extension Array where Element == NSLayoutConstraint {
    /// Sets the specified priority to every constriant.
    func setPriority(_ priority: Float) {
        for constraint in self {
            constraint.setPriority(priority)
        }
    }
}

extension NSLayoutConstraint {
    func setPriority(_ priority: Float) {
        self.priority = UILayoutPriority(priority)
    }
}
