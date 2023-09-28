import Foundation
import WebKit

/// Shows a new-style in-app message using a webView.
class WebInteractiveMessageAlertController: UIViewController,
                                            MiscEventListener,
                                            UserInteractionEventListener {
    struct Options {
        static func makeDefault () -> Self {
            Options(cornerRadius: MMInteractiveMessageAlertSettings.cornerRadius)
        }
        
        let cornerRadius: Float
    }
    
    private static let nibName = "WebInteractiveMessageAlertController"
    
    private let message: MMInAppMessage
    
    unowned var delegate: InAppMessageDelegate?
    private let msgView: WebInAppMessageView
    private let precalculatedMsgHeight: CGFloat
    
    /// Timer which schedules automatic dismiss of `msgView` if there is no user interaction
    private var mgsViewAutoDismissTimer: Timer?
    
    // MARK: - Script Interaction
    private let scriptEventRecipient: ScriptEventRecipient
    private let scriptMethodInvoker: ScriptMethodInvoker
    
    // MARK: - Fullscreen Constraints
    private var msgViewToLeftEdge: NSLayoutConstraint! // priority: 1000
    private var msgViewToRightEdge: NSLayoutConstraint! // priority: 1000
    private var msgViewToTopEdge: NSLayoutConstraint! // priority: 1000
    private var msgViewToBottomEdge: NSLayoutConstraint! // priority: 1000
    
    // MARK: - Popup Constraints
    private var msgViewCenterXToSafeArea: NSLayoutConstraint! // priority: 800
    private var msgViewCenterYToSafeArea: NSLayoutConstraint! // priority: 800
    private var msgViewTopWithinSafeArea: NSLayoutConstraint! // priority: 800
    private var msgViewBottomWithinSafeArea: NSLayoutConstraint! // priority: 800
    private var msgViewHeight: NSLayoutConstraint! // priority 700
    private var msgViewWidth: NSLayoutConstraint! // priority 700
    
    // MARK: - Init
    init(
        message: MMInAppMessage,
        webViewWithHeight: WebViewWithHeight,
        options: Options = Options.makeDefault()) {
            self.message = message
            
            msgView = WebInAppMessageView(webView: webViewWithHeight.webView)
            precalculatedMsgHeight = webViewWithHeight.height
            
            msgView.cornerRadius = CGFloat(options.cornerRadius)
            msgView.webView.scrollView.contentInsetAdjustmentBehavior = .never
            
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
        
        initializeConstraints()
        configureConstraints()
        
        msgView.webView.scrollView.alwaysBounceVertical = false
        msgView.webView.scrollView.alwaysBounceHorizontal = false
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        configureConstraints()
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
    
    private func initializeConstraints() {
        msgViewToTopEdge = msgView.topAnchor.constraint(equalTo: view.topAnchor)
        msgViewToBottomEdge = msgView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        msgViewToLeftEdge = msgView.leftAnchor.constraint(equalTo: view.leftAnchor)
        msgViewToRightEdge = msgView.rightAnchor.constraint(equalTo: view.rightAnchor)
        [msgViewToTopEdge, msgViewToBottomEdge, msgViewToLeftEdge, msgViewToRightEdge].setPriority(1000)
        
        msgViewCenterXToSafeArea = msgView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor)
        msgViewCenterYToSafeArea = msgView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        msgViewTopWithinSafeArea = msgView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor)
        msgViewBottomWithinSafeArea = msgView.topAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor)
        [msgViewCenterXToSafeArea, msgViewCenterYToSafeArea, msgViewTopWithinSafeArea, msgViewBottomWithinSafeArea].setPriority(800)
        
        msgViewWidth = msgView.widthAnchor.constraint(equalToConstant: view.frame.smallerDimension - 2 * inAppHorizontalMargin)
        msgViewHeight = msgView.heightAnchor.constraint(equalToConstant: precalculatedMsgHeight)
        [msgViewWidth, msgViewHeight].setPriority(700)
    }
    
    private func configureConstraints() {
        let fullscreenConstraints: [NSLayoutConstraint] = [
            msgViewToTopEdge,
            msgViewToBottomEdge,
            msgViewToLeftEdge,
            msgViewToRightEdge
        ]
        
        let popupConstraints: [NSLayoutConstraint] = [
            msgViewCenterXToSafeArea,
            msgViewCenterYToSafeArea,
            msgViewTopWithinSafeArea,
            msgViewBottomWithinSafeArea,
            msgViewWidth,
            msgViewHeight
        ]
        
        switch UIApplication.shared.interfaceOrientation {
        case .portrait, .portraitUpsideDown:
            switch message.type {
            case .popup:
                NSLayoutConstraint.deactivate(fullscreenConstraints)
                NSLayoutConstraint.activate(popupConstraints)
                break
            case .fullscreen:
                NSLayoutConstraint.activate(fullscreenConstraints)
                NSLayoutConstraint.deactivate(popupConstraints)
                break
            default:
                break
            }
        case .landscapeLeft, .landscapeRight:
            NSLayoutConstraint.deactivate(fullscreenConstraints)
            NSLayoutConstraint.activate(popupConstraints)
        default:
            break
        }
    }
    
    @objc
    private func dismissAndNotifyDelegate() {
        dismiss(animated: true) { self.delegate?.inAppMessageDidDismiss() }
    }
}

extension UIApplication {
    var interfaceOrientation: UIInterfaceOrientation {
        get {
            if #available(iOS 13.0, *) {
                return windows.first?.windowScene?.interfaceOrientation ?? .unknown
            } else {
                return statusBarOrientation
            }
        }
    }
}
