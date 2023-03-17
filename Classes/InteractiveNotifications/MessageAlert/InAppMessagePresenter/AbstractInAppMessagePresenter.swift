class AbstractInAppMessagePresenter<Resources>: InAppMessagePresenter, NamedLogger {
    /// The view controller which contains the message.
    private var messageController: InteractiveMessageAlertController?
    
    init(withDelegate delegate: InAppMessagePresenterDelegate) {
        self.delegate = delegate
    }
    
    // MARK: - InAppMessagePresenter
    internal unowned var delegate: InAppMessagePresenterDelegate
    
    final func loadResourcesAndPresentMessage() {
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
    
    // MARK: - Abstract
    /// Loads the resources and calls the handler with the resulting resources or `nil` depending on wheather the resources were successfuly loaded.
    func loadResources(completion completionHandler: @escaping (Resources?) -> Void) {
        preconditionFailure("not implemented")
    }
    
    /// Tries to create the view controller which will contain the message..
    func createMessageController(withResources: Resources?) -> InteractiveMessageAlertController? {
        preconditionFailure("not implemented")
    };
    
    // MARK: -
    /// Presents the message to the UI.
    /// - Precondition: Must be called on the **main thread**.
    private func presentMessageController(withResources resources: Resources?) {
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
}
