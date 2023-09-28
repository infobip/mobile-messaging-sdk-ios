/// Implementation of `InAppMessagePresenter` which shows an old-style in-app message as a native popup. Preloaded resource is an image.
class NativeInAppMessagePresenter: NamedLogger, InAppMessagePresenter, NativeInteractiveMessageAlertControllerDelegate {
    private let message: MM_MTMessage
    private let text: String
    private unowned let delegate: InAppMessagePresenterDelegate
    private var messageController: NativeInteractiveMessageAlertController?
    
    init(forMessage message: MM_MTMessage, text: String, withDelegate delegate: InAppMessagePresenterDelegate) {
        self.message = message
        self.text = text
        self.delegate = delegate
    }
    
    // MARK: - InAppMessagePresenter
    func presentMessage() {
        guard delegate.shouldLoadResources() else {
            self.delegate.didFailToPresent()
            return
        }

        loadImage() { [weak self] image in
            guard let self else { return }

            DispatchQueue.main.async() {
                self.present(image: image)
            }
        }
    }
    
    func dismissPresentedMessage() {
        self.messageController?.dismiss(animated: false)
    }
    
    // MARK: -
    private func loadImage(completion completionHandler: @escaping (Image?) -> Void) {
        guard let safeUrl = message.contentUrl?.safeUrl else {
            completionHandler(nil)
            return
        }

        logDebug("downloading image attachment \(String(describing: safeUrl))...")

        message.downloadImageAttachment() { (url, error) in
            if let url, let data = try? Data(contentsOf: url) {
                self.logDebug("image attachment downloaded")
                let image = DefaultImageProcessor().process(item: ImageProcessItem.data(data), options: [])
                completionHandler(image)
            } else {
                self.logDebug("could not download image attachment")
                completionHandler(nil)
            }
        }
    }
    
    private func present(image: Image?) -> Void {
        let category = message.getCategoryForInteractiveMessageAlertController()
        let newMessageController = createMessageControllerWithCategory(category, image: image)
        
        guard let presenterController = delegate.getPresenterViewController() else {
            logError("couldn't find the presenter view controller to present the message")
            delegate.didFailToPresent()
            return
        }

        self.messageController = newMessageController
        newMessageController.delegate = self
        presenterController.present(newMessageController, animated: true, completion: nil)
    }
    
    // MARK: - NativeInteractiveMessageAlertControllerDelegate
    func nativeInteractiveMessageAlertControllerDidDismissWithAction(_ action: MMNotificationAction, categoryId: String?) {
        self.delegate.didDismissMessage()
        self.messageController = nil
        
        MobileMessaging.handleAction(
            identifier: action.identifier,
            category: categoryId,
            message: self.message,
            notificationUserInfo: self.message.originalPayload,
            userText: nil,
            completionHandler: {}
        )
    }
    
    // MARK: -
    private func createMessageControllerWithCategory(_ category: MMNotificationCategory?, image: Image?) -> NativeInteractiveMessageAlertController {
        if let category {
            return NativeInteractiveMessageAlertController(
                titleText: message.title,
                messageText: text,
                imageURL: nil,
                image: image,
                category: category)
        } else {
            return NativeInteractiveMessageAlertController(
                titleText: message.title,
                messageText: text,
                imageURL: nil,
                image: image,
                dismissTitle: message.inAppDismissTitle,
                openTitle: message.inAppOpenTitle)
        }
    }
}

fileprivate extension MM_MTMessage {
    func getCategoryForInteractiveMessageAlertController() -> MMNotificationCategory? {
        if let categoryId = self.category,
           let category = MobileMessaging.category(withId: categoryId),
           category.actions.first(where: { return $0 is MMTextInputNotificationAction } ) == nil {
            return category
        }
        return nil
    }
}
