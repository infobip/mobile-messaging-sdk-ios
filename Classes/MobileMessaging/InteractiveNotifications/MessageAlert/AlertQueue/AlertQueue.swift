/// Holds a sequence of `AlertOperation` instances and makes sure they are executed synchronously and safely with respect to application's "active" state.
class AlertQueue {
	static let sharedInstace = AlertQueue()
	
	lazy var operationQueue: Foundation.OperationQueue = {
		let ret = Foundation.OperationQueue()
        // Make sure only one `AlertOperation` instance at most can be active at a time.
		ret.maxConcurrentOperationCount = 1
        return ret
	}()
	
	init() {
		setupObservers()
		// The queue must perform operations only in apps active state.
		operationQueue.isSuspended = !MobileMessaging.application.isInForegroundState
	}
	
	private func setupObservers() {
		guard !isTestingProcessRunning else {
			return
		}
        
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(self.handleAppWillResignActive(notification:)),
			name: UIApplication.willResignActiveNotification, object: nil)

		NotificationCenter.default.addObserver(
			self,
			selector: #selector(self.handleDidBecomeActive(notification:)),
			name: UIApplication.didBecomeActiveNotification, object: nil)
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	@objc private func handleDidBecomeActive(notification: Notification) {
		operationQueue.isSuspended = false
	}

	@objc private func handleAppWillResignActive(notification: Notification) {
		operationQueue.isSuspended = true
	}
	
	func cancelAllAlerts() {
		operationQueue.cancelAllOperations()
	}
	
	func enqueueAlert(message: MM_MTMessage, text: String) {
        let operation = AlertOperation(withMessage: message, text: text)
		operationQueue.addOperation(operation)
	}
}

