import WebKit

/// The client which contains all logic concerning interaction with in-app message's script.
class InAppMessageScriptClient {
    private static let inAppMessageScriptApiNamespace = "InfobipMobileMessaging.mobileSdkApi";
    
    private let webView: WKWebView
    
    init (webView: WKWebView) {
        self.webView = webView
    }
    
    // MARK: - Calling in-app message script's methods
    func registerMessageSendingOnDocumentLoad(_ completionHandler: ((DocumentReadyState?, (any Error)?) -> Void)?) {
        callInAppMessageScriptMethod(ScriptMethodNames.registerMessageSendingOnDocumentLoad.rawValue) {
            readyStateRaw, error in 
            if let readyStateRaw = readyStateRaw as? String,
               let readyState = DocumentReadyState(rawValue: readyStateRaw) {
                completionHandler?(readyState, error)
            } else {
                completionHandler?(nil, error)
            }
        }
    }
    
    private func callInAppMessageScriptMethod(_ methodName: String, completionHandler: ((Any?, (any Error)?) -> Void)?) {
        webView.evaluateJavaScript(
            "\(InAppMessageScriptClient.inAppMessageScriptApiNamespace).\(methodName)()",
            completionHandler: completionHandler)
    }
    
    private enum ScriptMethodNames: String {
        case registerMessageSendingOnDocumentLoad
    }
    
    // MARK: -
    /// Possible value of browser's `document.readyState`.
    enum DocumentReadyState: String {
        /// The document is loading
        case loading
        /// The document was fully read.
        case interactive
        /// The document and all resources were loaded.
        case complete
    }
    
    // MARK: - Listening to in-app message script's messages
    func onInAppMessageClosed(execute action: @escaping (WKScriptMessage) -> Void) {
        onMessage(MessageNames.close.rawValue, call: action)
    }
    
    func onHeightChanged(execute action: @escaping (WKScriptMessage) -> Void) {
        onMessage(MessageNames.heightChanged.rawValue, call: action)
    }
    
    func onDocumentWasLoaded(execute action: @escaping (WKScriptMessage) -> Void) {
        onMessage(MessageNames.documentWasLoaded.rawValue, call: action)
    }
    
    private enum MessageNames: String {
        /// Sent when the document and all resources have been loaded.
        case documentWasLoaded
        /// Sent when in-app message is dismissed due to interaction with its html content.
        case close
        /// Sent when height of the page changes.
        case heightChanged
    }
    
    // MARK: - Easier script message handling
    /// Registers the provided callback which will be called when in-app message's script sent the specified message.
    private func onMessage(_ name: String, call handler: @escaping (WKScriptMessage) -> Void) {
        webView.configuration.userContentController.add(MessageHandler(action: handler), name: name)
    }
    
    /// A generic message handler which simplifies handling of messages sent by in-app message's script by using only closures.
    private class MessageHandler: NSObject, WKScriptMessageHandler {
        private var handler: (WKScriptMessage) -> Void
        
        init(action: @escaping (WKScriptMessage) -> Void) {
            self.handler = action
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            handler(message)
        }
    }
}
