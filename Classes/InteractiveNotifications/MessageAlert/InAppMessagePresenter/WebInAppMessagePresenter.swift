import WebKit

typealias WebViewWithHeight = (webView: WKWebView, height: CGFloat)

/// Implementation of `InAppMessagePresenter` which shows a new-style web in-app message inside a web view.
class WebInAppMessagePresenter: NamedLogger, InAppMessagePresenter {
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
    
    private let message: MMInAppMessage
    private var webView: WKWebView?
    private var webViewDelegate: WebViewPreloadingDelegate?
    private var shouldPreload: Bool
    private unowned var delegate: InAppMessagePresenterDelegate
    private var messageController: InteractiveMessageAlertController?
    private var bannerManager: WebInAppBannerManager?
    
    init(forMessage message: MMInAppMessage,
         withDelegate delegate: InAppMessagePresenterDelegate,
         shouldPreload: Bool) {
        self.message = message
        self.shouldPreload = shouldPreload
        self.delegate = delegate
    }
    
    // MARK: - InAppMessagePresenter
    func presentMessage() {
        guard delegate.shouldLoadResources() else { return }
        
        prepareWebView() { [weak self] webViewWithHeight in
            guard let self else { return }
            
            DispatchQueue.main.async() {
                self.present(webViewWithHeight: webViewWithHeight)
            }
        }
    }
    
    func dismissPresentedMessage() {
        // We don't know weather we have `controller` or `bannerManager` so we dismiss both
        self.messageController?.dismiss(animated: false)
        self.bannerManager?.dismiss()
    }
    
    private func prepareWebView(completion completionHandler: @escaping (WebViewWithHeight?) -> Void) {
        DispatchQueue.main.async() { [self] in
            if shouldPreload {
                guard let appWindow else { return completionHandler(nil) }
                let webView = WKWebView()
                self.webView = webView
                webViewDelegate = WebViewPreloadingDelegate(withCompletion: {[weak self] webViewWithHeight in
                    completionHandler(webViewWithHeight)
                    self?.delegate.didPresent()
                })
                webView.navigationDelegate = webViewDelegate
                webView.frame.width = calculateInAppMessageWidth(superFrame: appWindow.frame, margin: 8)
                webView.load(URLRequest(url: message.url))
            } else {
                completionHandler(nil)
            }
        }
    }
    
    private func present(webViewWithHeight: WebViewWithHeight?) -> Void {
        if message.type != .banner {
            guard let newMessageController = createMessageController(webViewWithHeight: webViewWithHeight) else {
                logError("couldn't create the view controller for the message")
                delegate.didFailToPresent()
                return
            }

            guard let presenterController = delegate.getPresenterViewController() else {
                logError("couldn't find the presenter view controller to present the message")
                delegate.didFailToPresent()
                return
            }

            self.messageController = newMessageController

            newMessageController.dismissHandler = { [unowned self] in
                self.delegate.didDismissMessage()
                self.messageController = nil
            }
            presenterController.present(newMessageController, animated: true, completion: nil)
        } else {
            let newBannerManager = WebInAppBannerManager(message: message, webViewWithHeight: webViewWithHeight)
            self.bannerManager = newBannerManager
            newBannerManager.dismissHandler = {
                [unowned self] in
                self.delegate.didDismissMessage()
                self.bannerManager = nil
            }
            newBannerManager.startPresenting()
        }
    }

    private func createMessageController(webViewWithHeight: WebViewWithHeight?) -> InteractiveMessageAlertController? {
        return WebInteractiveMessageAlertController(message: message, webViewWithHeight: webViewWithHeight)
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
        
        InAppMessageScriptClient(webView: webView).readBodyHeight { [weak self] height, error in
            if let height {
                self?.completionHandler((webView, height))
            } else {
                self?.completionHandler(nil)
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
    superFrame.width - margin * 2
}
