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
        guard notCancelledNorMessageExpired else {
            cancelPresenter()
            return
        }
        
        
        guard let _presenter = createPresenter() else {
            semaphore.signal()
            return
        }
        
        presenter = _presenter
        
        MobileMessaging.sharedInstance?.interactiveAlertManager?.delegate?.willDisplay(self.message)
        presenter?.presentMessage()
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
        notCancelledNorMessageExpired
    }
    
    func getPresenterViewController() -> UIViewController? {
        guard notCancelledNorMessageExpired else { return nil }
        
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
    
    func didPresent() {
        MobileMessaging.sharedInstance?.setSeen(userInitiated: false, messageIds: [message.messageId], immediately: true, completion: {})
    }
    
    // MARK: -
    private var notCancelledNorMessageExpired: Bool { !isCancelled && !message.isExpired }
    
    /// Creates the appropriate `InAppMessagePresenter` depending on the type of the message.
    private func createPresenter() -> (any InAppMessagePresenter)? {
        if let inAppMessage = message as? MMInAppMessage {
            return WebInAppMessagePresenter(forMessage: inAppMessage, withDelegate: self, inAppsEnabled: MobileMessaging.sharedInstance?.fullFeaturedInAppsEnabled ?? false)
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
