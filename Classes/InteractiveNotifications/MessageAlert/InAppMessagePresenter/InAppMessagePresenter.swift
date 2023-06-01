/// Loads message resources and presents the message to the UI.
protocol InAppMessagePresenter: AnyObject {
    /// Asynchronously loads message resources and shows the message to the UI.
    func presentMessage()
    
    /// Dismisses the presented message if there is one.
    /// - Precondition: Must be called on the **main thread**.
    func dismissPresentedMessage()
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
    
    /// Called when presented the message successfully.
    func didPresent()
}
