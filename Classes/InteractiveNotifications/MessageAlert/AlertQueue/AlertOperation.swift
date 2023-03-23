/// Presents the in-app message and waits until it is dismissed, or dismisses it manually if the alert operation gets cancelled. It uses the appropriate
/// implementation of `InAppMessagePresenter` depending on the type of the in-app message (old-style native type or new-style web type).
class AlertOperation: Foundation.Operation, NamedLogger, InAppMessagePresenterDelegate {
    let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
    let message: MM_MTMessage
    let text: String
    
    private var presenter: (any InAppMessagePresenter)?
    
    init(withMessage message: MM_MTMessage, text: String) {
        self.message = message
        self.text = text
        super.init()
        self.addObserver(self, forKeyPath: "isCancelled", options: NSKeyValueObservingOptions.new, context: nil)
    }
    
    deinit {
        self.removeObserver(self, forKeyPath: "isCancelled")
    }
    
    override func main() {
        guard isCancelledOrMessageExpired else {
            cancelPresenter()
            return
        }
        
        presenter = createPresenter()
        guard let presenter else { preconditionFailure("presenter got deallocated") }
    
        MobileMessaging.sharedInstance?.interactiveAlertManager?.delegate?.willDisplay(self.message)
        presenter.loadResourcesAndPresentMessage()
        waitUntilAlertDismissed()
    }

    // MARK: - Semaphore
    private func waitUntilAlertDismissed() {
        semaphore.wait()
    }

    private func notifyAlertDismissed() {
        semaphore.signal()
    }

    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "isCancelled" {
            if (change?[NSKeyValueChangeKey.newKey] as? Bool ?? false) == true {
                cancelPresenter()
            }
        } else {
            return
        }
    }
    
    // MARK: - InAppMessagePresenterDelegate
    func shouldLoadResources() -> Bool {
        isCancelledOrMessageExpired
    }
        
    func getPresenterViewController() -> UIViewController? {
        guard isCancelledOrMessageExpired else { return nil }
        
        return MobileMessaging.messageHandlingDelegate?.inAppPresentingViewController?(for: message)
        ?? MobileMessaging.application.visibleViewController
    }
    
    func didDismissMessage() {
        notifyAlertDismissed()
    }
    
    func didFailToPresent() {
        logError("in-app message couldn't be presented")
        notifyAlertDismissed()
    }
    
    // MARK: -
    private var isCancelledOrMessageExpired: Bool { !isCancelled && !message.isExpired }

    /// Creates the appropriate `InAppMessagePresenter` depending on the type of the message.
    private func createPresenter() -> any InAppMessagePresenter {
        if let inAppMessage = message as? MMInAppMessage {
            return WebInAppMessagePresenter(forMessage: inAppMessage, withDelegate: self, shouldPreload: true)
        } else {
            return NativeInAppMessagePresenter(forMessage: message, text: message.text ?? "", withDelegate: self)
        }
    }

    private func cancelPresenter() {
        logDebug("canceled. Message expired?: \(message.isExpired.description)")
        DispatchQueue.main.async() {
            self.presenter?.dismissPresentedMessage()
        }
        notifyAlertDismissed()
    }
}
