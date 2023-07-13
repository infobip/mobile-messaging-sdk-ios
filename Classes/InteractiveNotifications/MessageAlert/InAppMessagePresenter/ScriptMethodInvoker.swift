import WebKit

/// A client for calling methods of in-app message script's API.
class ScriptMethodInvoker: NamedLogger {
    /// The namespace all methods exposed by in-app message's script belong to.
    private static let inAppMessageScriptApiNamespace = "InfobipMobileMessaging";
    
    private let webView: WKWebView
    
    init (webView: WKWebView) {
        self.webView = webView
    }
    
    func readBodyHeight(_ completionHandler: ((CGFloat?, (any Error)?) -> Void)?) {
        callInAppMessageScriptMethod(ScriptMethodNames.readBodyHeight.rawValue) { heightRaw, error in
            if let height = heightRaw as? CGFloat {
                completionHandler?(height, error)
            } else {
                self.logError("couldn't read height from the result of invoking \(ScriptMethodNames.readBodyHeight)")
                completionHandler?(nil, error)
            }
        }
    }
    
    func registerMessageSendingOnDocumentLoad(_ completionHandler: ((DocumentReadyState?, (any Error)?) -> Void)?) {
        callInAppMessageScriptMethod(ScriptMethodNames.registerMessageSendingOnDocumentLoad.rawValue) {
            readyStateRaw, error in
            if let readyStateRaw = readyStateRaw as? String,
               let readyState = DocumentReadyState(rawValue: readyStateRaw) {
                completionHandler?(readyState, error)
            } else {
                self.logError("couldn't document statefrom the result of invoking \(ScriptMethodNames.registerMessageSendingOnDocumentLoad)")
                completionHandler?(nil, error)
            }
        }
    }
    
    /// Calls the specified method of script's API and calls completion handler with the result or an error.
    private func callInAppMessageScriptMethod(_ methodName: String, completionHandler: ((Any?, (any Error)?) -> Void)?) {
        webView.evaluateJavaScript(
            "\(ScriptMethodInvoker.inAppMessageScriptApiNamespace).\(methodName)()",
            completionHandler: completionHandler)
    }
}

/// Names of all methods supported by in-app message's script API.
private enum ScriptMethodNames: String {
    case readBodyHeight
    case registerMessageSendingOnDocumentLoad
}
