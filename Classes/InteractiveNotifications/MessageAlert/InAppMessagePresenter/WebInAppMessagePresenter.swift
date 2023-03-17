import WebKit

/// Implementation of `InAppMessagePresenter` which shows a new-style web in-app message inside a web view.
class WebInAppMessagePresenter: AbstractInAppMessagePresenter<WKWebView> {
    /// How will the preload be handled before the presentation.
    enum PreloadMode {
        /// No prealoding. The `webView` is sent immediatelly to presentation as the page is being loaded inside it.
        case noPreload
        /// Waits until `webView` declares that loading has finished.
        case waitWebViewDidFinish
        /// Waits until `webView` declares that loading has finished and then waits further until document is fully loaded (DOM and all resources are ready).
        case waitForDocumentLoaded
    }
    
    private let message: MMInAppMessage
    private var webView: WKWebView?
    private var webViewDelegate: WebViewPreloadingDelegate?
    private var preloadMode: PreloadMode
    
    init(forMessage message: MMInAppMessage,
         withDelegate delegate: InAppMessagePresenterDelegate,
         withPreloadMode preloadMode: PreloadMode = .waitForDocumentLoaded) {
        self.message = message
        self.preloadMode = preloadMode
        super.init(withDelegate: delegate)
    }
    
    override func loadResources(completion completionHandler: @escaping (WKWebView?) -> Void) {
        DispatchQueue.main.async() { [self] in
            webView = WKWebView()
            guard let webView else { preconditionFailure("webView deallocated") }
            
            switch (preloadMode) {
            case .noPreload:
                webView.load(URLRequest(url: message.url))
                completionHandler(webView)
            case .waitWebViewDidFinish, .waitForDocumentLoaded:
                let waitForDocumentLoaded = preloadMode == .waitForDocumentLoaded
                webViewDelegate = WebViewPreloadingDelegate(waitForDocumentLoaded: waitForDocumentLoaded,
                                                            withCompletion: completionHandler)
                webView.navigationDelegate = webViewDelegate
                webView.load(URLRequest(url: message.url))
            }
        }
    }
    
    override func createMessageController(withResources webView: WKWebView?) -> InteractiveMessageAlertController? {
        guard let webView else { return nil }
        return WebInteractiveMessageAlertController(message: message, webView: webView)
    }
}

/// Delegate for web view which makes sure web view is ready for presentation, then it calls the provided callback with `webView`. If something fails it calls the
/// callback with `nil`.
class WebViewPreloadingDelegate: NSObject, WKNavigationDelegate, NamedLogger {
    private let waitForDocumentLoaded: Bool
    private let completionHandler: (WKWebView?) -> Void
    
    init(waitForDocumentLoaded: Bool, withCompletion completionHandler: @escaping (WKWebView?) -> Void) {
        self.waitForDocumentLoaded = waitForDocumentLoaded
        self.completionHandler = completionHandler
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        unasignSelfAsDelegate(webView: webView)
        
        if (waitForDocumentLoaded) {
            let inAppMesssageScripClient = InAppMessageScriptClient(webView: webView)
            
            inAppMesssageScripClient.onDocumentWasLoaded() { [self] _ in
                logDebug("document is fully loaded and ready")
                completionHandler(webView)
            }
            
            inAppMesssageScripClient.registerMessageSendingOnDocumentLoad() { [self] readyState, _ in
                if let readyState {
                    logDebug("document's ready state: \(readyState.rawValue)")
                } else {
                    logDebug("failed to read document's ready state")
                }
            }
        } else {
            completionHandler(webView)
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
