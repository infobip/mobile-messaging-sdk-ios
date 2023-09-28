import WebKit

/// Protocol through which `InAppMessageScriptEventRecipient` notifies about any received event.
protocol InAppMessageScriptEventListener: AnyObject {}

protocol MiscEventListener: InAppMessageScriptEventListener {
    func scriptEventRecipientDidDetectDocumentState(_ state: DocumentReadyState) -> Void
    func scriptEventRecipientDidDetectChangeOfHeight(_ height: Double) -> Void
}

protocol UserInteractionEventListener: InAppMessageScriptEventListener {
    func scriptEventRecipientDidDetectOpenAppPage(withDeeplink deeplink: String)
    func scriptEventRecipientDidDetectOpenBrowser(withUrl url: String)
    func scriptEventRecipientDidDetectOpenWebView(withUrl url: String)
    func scriptEventRecipientDidDetectClose() -> Void
}

/// A client for listening events sent by in-app message's script.
class ScriptEventRecipient: NSObject, WKScriptMessageHandler, NamedLogger {
    private let webView: WKWebView
    
    /// Listener to whom processed and adapted events will be sent.
    weak var listener: InAppMessageScriptEventListener?
    
    init (webView: WKWebView) {
        self.webView = webView
        
        super.init()
        
        MiscEvent.allCases.forEach {
            self.webView.configuration.userContentController.add(self, name: $0.rawValue)
        }
        UserInteractionEvent.allCases.forEach {
            self.webView.configuration.userContentController.add(self, name: $0.rawValue)
        }
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let eventName = MiscEvent(rawValue: message.name) {
            handleMiscEvent(eventName, message: message)
        } else if let eventName = UserInteractionEvent(rawValue: message.name) {
            handleUserInteractionEvent(eventName, message: message)
        }
    }
    
    // MARK: -
    private func handleUserInteractionEvent(_ eventName: UserInteractionEvent, message: WKScriptMessage) -> Void {
        guard let listener = listener as? UserInteractionEventListener,
                let url = message.body as? String else {
            return
        }
        
        switch eventName {
        case .openAppPage:
            listener.scriptEventRecipientDidDetectOpenAppPage(withDeeplink: url)
        case .openBrowser:
            listener.scriptEventRecipientDidDetectOpenBrowser(withUrl: url)
        case .openWebView:
            listener.scriptEventRecipientDidDetectOpenWebView(withUrl: url)
        case .close:
            listener.scriptEventRecipientDidDetectClose()
        }
    }
    
    private func handleMiscEvent(_ eventName: MiscEvent, message: WKScriptMessage) -> Void {
        guard let listener = listener as? MiscEventListener else { return }
        
        switch eventName {
        case .documentWasLoaded:
            if let readyStateRaw = message.body as? String,
               let readyState = DocumentReadyState(rawValue: readyStateRaw) {
                listener.scriptEventRecipientDidDetectDocumentState(readyState)
            }
        case .heightChanged:
            if let height = self.extractHeightFromMessage(message) {
                listener.scriptEventRecipientDidDetectChangeOfHeight(height)
            }
        }
    }
    
    private func extractHeightFromMessage(_ message: WKScriptMessage) -> Double? {
        guard let height = (message.body as? NSNumber)?.doubleValue else {
            logError("script didn't send a valid height number")
            return nil
        }
        return height
    }
    
    deinit {
        MiscEvent.allCases.forEach {
            self.webView.configuration.userContentController.removeScriptMessageHandler(forName: $0.rawValue)
        }
        UserInteractionEvent.allCases.forEach {
            self.webView.configuration.userContentController.removeScriptMessageHandler(forName: $0.rawValue)
        }
    }
}

private enum UserInteractionEvent: String, CaseIterable {
    /// Sent when primary button is pressed and it sends a deepling to be opened as a new application page.
    case openAppPage
    /// Sent when primary button is pressed and it sends an url to be opened inside a browser window.
    case openBrowser
    /// Sent when primary button is pressed and it sends an url to be opened inside a web view.
    case openWebView
    /// Sent when in-app message is dismissed due to interaction with its html content.
    case close
}

private enum MiscEvent: String, CaseIterable {
    /// Sent when the document and all resources have been loaded.
    case documentWasLoaded
    /// Sent when height of the page changes.
    case heightChanged
}
