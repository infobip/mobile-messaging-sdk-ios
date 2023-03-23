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
    
    typealias Resources = WebViewWithHeight
    
    private let message: MMInAppMessage
    private var webView: WKWebView?
    private var webViewDelegate: WebViewPreloadingDelegate?
    private var shouldPreload: Bool
    unowned var delegate: InAppMessagePresenterDelegate
    var messageController: InteractiveMessageAlertController?
    
    init(forMessage message: MMInAppMessage,
         withDelegate delegate: InAppMessagePresenterDelegate,
         shouldPreload: Bool) {
        self.message = message
        self.shouldPreload = shouldPreload
        self.delegate = delegate
    }
    
    func loadResources(completion completionHandler: @escaping (WebViewWithHeight?) -> Void) {
        DispatchQueue.main.async() { [self] in
            if shouldPreload {
                guard let appWindow else { return completionHandler(nil) }
                let webView = WKWebView()
                self.webView = webView
                webViewDelegate = WebViewPreloadingDelegate(withCompletion: completionHandler)
                webView.navigationDelegate = webViewDelegate
                webView.frame.width = calculateInAppMessageWidth(superFrame: appWindow.frame, margin: 8)
                webView.load(URLRequest(url: message.url))
            } else {
                completionHandler(nil)
            }
        }
    }
    
    func createMessageController(withResources webViewWithHeight: WebViewWithHeight?) -> InteractiveMessageAlertController? {
        return WebInteractiveMessageAlertController(message: message, webViewWithHeight: webViewWithHeight)
    }
}

/// Delegate for web view which makes sure web view is ready for presentation, then it calls the provided callback with `webView`. If something fails it calls the
/// callback with `nil`.
class WebViewPreloadingDelegate: NSObject, WKNavigationDelegate, NamedLogger {
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

func calculateInAppMessageWidth(superFrame: CGRect, margin: CGFloat) -> CGFloat {
    superFrame.width - margin * 2
}
