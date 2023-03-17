/// Loads message resources and presents the message to the UI.
protocol InAppMessagePresenter: AnyObject {
    associatedtype Resources
    var delegate: InAppMessagePresenterDelegate { get set }
    var messageController: InteractiveMessageAlertController? { get set }
    
    /// Asynchronously loads message resources and shows the message to the UI.
    func loadResourcesAndPresentMessage()
    
    /// Dismisses the presented message if there is one.
    /// - Precondition: Must be called on the **main thread**.
    func dismissPresentedMessage()
    
    func loadResources(completion completionHandler: @escaping (Resources?) -> Void)
    
    /// Tries to create the view controller which will contain the message..
    func createMessageController(withResources: Resources?) -> InteractiveMessageAlertController?
}

/// Protocol which provides one the ability to control `InAppMessagePresenter`'s behavior, listen to its progress and also supply it with information which
/// it cannot acquire by itself.
protocol InAppMessagePresenterDelegate: AnyObject {
    /// Called when resources are about to be loaded.
    /// - Returns: An instruction wheather to continue the process.
    func shouldLoadResources() -> Bool
    
    /// Called when `InAppMessagePresenter` needs a presenting view controller to present the message.
    /// - Returns: The view controller which will be used to present the message. If it's `nil`, the process will not continue.
    func getPresenterViewController() -> UIViewController?
    
    /// Called after the message has been dismissed.
    func didDismissMessage()
    
    /// Called when it becomes evidend that the message cannot be presented.
    func didFailToPresent()
}

extension InAppMessagePresenter where Self: NamedLogger {
    func presentMessageController(withResources resources: Resources?) {
        guard let newMessageController = createMessageController(withResources: resources) else {
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

        newMessageController.dismissHandler = { [unowned self] in self.delegate.didDismissMessage() }
        presenterController.present(newMessageController, animated: true, completion: nil)

    }
    
    func loadResourcesAndPresentMessage() {
        guard delegate.shouldLoadResources() else { return }
        
        loadResources() { [weak self] resources in
            guard let self else { return }
            
            DispatchQueue.main.async() {
                self.presentMessageController(withResources: resources)
            }
        }
    }
    
    func dismissPresentedMessage() {
        self.messageController?.dismiss(animated: false) {
            self.delegate.didDismissMessage()
        }
    }
}
