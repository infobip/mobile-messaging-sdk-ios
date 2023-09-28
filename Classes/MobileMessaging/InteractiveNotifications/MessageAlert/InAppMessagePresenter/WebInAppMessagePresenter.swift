import WebKit

/// The minimal distance between in-app message and the edge of the screen.
let inAppHorizontalMargin: CGFloat = 8

typealias WebViewWithHeight = (webView: WKWebView, height: CGFloat)

/// Protocol through which popup and banner notifiy about actions and dismissal.
protocol InAppMessageDelegate: AnyObject {
    func inAppMessageDidDismiss();
    func inAppMessageDidReceiveAction(_ action: String, internalDataKey: String, url: String);
    func inAppMessageDidClose() -> Void
}

/// Implementation of `InAppMessagePresenter` which shows a new-style web in-app message inside a web view.
class WebInAppMessagePresenter: NamedLogger,
                                InAppMessagePresenter,
                                InAppMessageDelegate {
    private var appWindow: UIWindow? {
        get {
            if #available(iOS 13.0, *) {
                return UIApplication.shared.connectedScenes
                    .first { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
                    .map { $0 as? UIWindowScene }
                    .flatMap { $0?.windows.first } ?? UIApplication.shared.delegate?.window ?? UIApplication.shared.keyWindow
            }
            
            return UIApplication.shared.delegate?.window ?? nil
        }
    }
    
    private static let requestTimeout: TimeInterval = 15.0 // seconds
    private let message: MMInAppMessage
    private var webView: WKWebView?
    private var webViewDelegate: WebViewPreloadingDelegate?
    private unowned let delegate: InAppMessagePresenterDelegate
    private var messageController: WebInteractiveMessageAlertController?
    private var bannerManager: WebInAppBannerManager?
    
    init?(forMessage message: MMInAppMessage, withDelegate delegate: InAppMessagePresenterDelegate, inAppsEnabled fullFeaturedInAppsEnabled: Bool) {
        guard fullFeaturedInAppsEnabled else {
            MMLogDebug("FullFeaturedInApps are disabled. In order to use, enable by calling withFullFeaturedInApps() on MobileMessaging.start()")
            return nil
        }
        self.message = message
        self.delegate = delegate
    }
    
    // MARK: - InAppMessagePresenter
    func presentMessage() {
        guard delegate.shouldLoadResources() else {
            self.delegate.didFailToPresent()
            return
        }
        
        prepareWebView() { [weak self] webViewWithHeight in
            guard let self else { return }
            
            guard let webViewWithHeight else {
                self.delegate.didFailToPresent()
                return
            }
            
            DispatchQueue.main.async() {
                self.present(webViewWithHeight: webViewWithHeight)
            }
        }
    }
    
    func dismissPresentedMessage() {
        // We don't know weather we have `controller` or `bannerManager` so we dismiss both.
        self.messageController?.dismiss(animated: false)
        self.bannerManager?.dismiss()
    }
    
    private func prepareWebViewURLRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: message.url, timeoutInterval: WebInAppMessagePresenter.requestTimeout)
        guard let applicationCode = MobileMessaging.sharedInstance?.applicationCode else {
            return request
        }
        request.setValue("App \(applicationCode)", forHTTPHeaderField: "Authorization")
        request.setValue(MobileMessaging.userAgent.currentUserAgentString, forHTTPHeaderField: "User-Agent")
        request.setValue(MobileMessaging.sharedInstance?.currentInstallation().pushRegistrationId, forHTTPHeaderField: Consts.APIHeaders.pushRegistrationId)
        
        return request
    }
    
    // MARK: - InAppMessageDelegate
    func inAppMessageDidDismiss() {
        dismissAndCleanup()
    }
    
    func inAppMessageDidReceiveAction(_ action: String, internalDataKey: String, url: String) {
        let newMessage = message.withNewInternalData { oldInternalData in
            var newInternalData = oldInternalData
            newInternalData[internalDataKey] = url
            return newInternalData
        }
        dismissAndHandleAction(action, withMessage: newMessage)
    }
    
    func inAppMessageDidClose() {
        dismissAndHandleAction(MMNotificationAction.DismissActionId, withMessage: message)
    }
    
    // MARK: -
    private func prepareWebView(completion completionHandler: @escaping (WebViewWithHeight?) -> Void) {
        DispatchQueue.main.async() { [self] in
            guard let appWindow else { return completionHandler(nil) }
            let webView = WKWebView()
            self.webView = webView
            webViewDelegate = WebViewPreloadingDelegate(withCompletion: {[weak self] webViewWithHeight in
                completionHandler(webViewWithHeight)
                self?.delegate.didPresent()
            })
            webView.navigationDelegate = webViewDelegate
            webView.frame.size.width = appWindow.frame.smallerDimension - 2 * inAppHorizontalMargin
            let request = prepareWebViewURLRequest(url: message.url)
            webView.load(request)
        }
    }
    
    private func present(webViewWithHeight: WebViewWithHeight) -> Void {
        if message.type != .banner {
            let newMessageController = WebInteractiveMessageAlertController(message: message,
                                                                            webViewWithHeight: webViewWithHeight)
            
            guard let presenterController = delegate.getPresenterViewController() else {
                logError("couldn't find the presenter view controller to present the message")
                delegate.didFailToPresent()
                return
            }
            
            self.messageController = newMessageController
            newMessageController.delegate = self
            presenterController.present(newMessageController, animated: true, completion: nil)
        } else {
            let newBannerManager = WebInAppBannerManager(message: message, webViewWithHeight: webViewWithHeight)
            self.bannerManager = newBannerManager
            newBannerManager.delegate = self
            newBannerManager.startPresenting()
        }
    }
    
    private func dismissAndHandleAction(_ actionId: String, withMessage message: MM_MTMessage?) {
        dismissAndCleanup()
        
        MobileMessaging.handleAction(
            identifier: actionId,
            category: nil,
            message: message,
            notificationUserInfo: message?.originalPayload,
            userText: nil,
            completionHandler: {}
        )
    }
    
    private func dismissAndCleanup() {
        delegate.didDismissMessage()
        
        self.messageController = nil
        self.bannerManager = nil
        self.webView?.stopLoading()
    }
}

/// Delegate for web view which makes sure web view is ready for presentation, then it calls the provided callback with `webView`. If something fails it calls the
/// callback with `nil`.
private class WebViewPreloadingDelegate: NSObject, WKNavigationDelegate, NamedLogger {
    private let completionHandler: (WebViewWithHeight?) -> Void
    
    init(withCompletion completionHandler: @escaping (WebViewWithHeight?) -> Void) {
        self.completionHandler = completionHandler
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        unasignSelfAsDelegate(webView: webView)
        
        ScriptMethodInvoker(webView: webView).readBodyHeight { [weak self] height, error in
            if let self {
                if let height {
                    self.completionHandler((webView, height))
                } else {
                    self.completionHandler(nil)
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        unasignSelfAsDelegate(webView: webView)
        self.completionHandler(nil)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        unasignSelfAsDelegate(webView: webView)
        self.completionHandler(nil)
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        unasignSelfAsDelegate(webView: webView)
        self.completionHandler(nil)
    }
    
    // MARK: -
    private func unasignSelfAsDelegate(webView: WKWebView) {
        if webView.navigationDelegate === self {
            webView.navigationDelegate = nil
        }
    }
}

internal func calculateInAppMessageWidth(superFrame: CGRect, margin: CGFloat) -> CGFloat {
    return superFrame.width - margin * 2
}

fileprivate extension MM_MTMessage {
    typealias InternalDataProducer = (_ oldInternalData: MMStringKeyPayload) -> MMStringKeyPayload
    
    /// Creates a copy of this message with new `internalData` produced by `internalDataProducer`.
    func withNewInternalData(_ internalDataProducer: InternalDataProducer) -> MM_MTMessage? {
        var newOriginalPayload = originalPayload
        if let oldInternalData = newOriginalPayload[Consts.APNSPayloadKeys.internalData] as? MMStringKeyPayload {
            newOriginalPayload[Consts.APNSPayloadKeys.internalData] = internalDataProducer(oldInternalData)
        }
        
        return MM_MTMessage(
            payload: newOriginalPayload,
            deliveryMethod: deliveryMethod,
            seenDate: seenDate,
            deliveryReportDate: deliveryReportedDate,
            seenStatus: seenStatus,
            isDeliveryReportSent: isDeliveryReportSent)
    }
}

extension CGRect {
    var smallerDimension: CGFloat {
        get {
            return min(height, width)
        }
    }
}
