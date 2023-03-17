/// Implementation of `InAppMessagePresenter` which shows an old-style in-app message as a native popup. Preloaded resource is an image.
class NativeInAppMessagePresenter: AbstractInAppMessagePresenter<Image> {
    private let message: MM_MTMessage
    private let text: String
    
    init(forMessage message: MM_MTMessage, text: String, withDelegate delegate: InAppMessagePresenterDelegate) {
        self.message = message
        self.text = text
        super.init(withDelegate: delegate)
    }
    
    override func loadResources(completion completionHandler: @escaping (Image?) -> Void) {
        guard let safeUrl = message.contentUrl?.safeUrl else { return }
        
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
    
    override func createMessageController(withResources image: Image?) -> InteractiveMessageAlertController {
        if let categoryId = message.category,
           let category = MobileMessaging.category(withId: categoryId),
           category.actions.first(where: { return $0 is MMTextInputNotificationAction } ) == nil {
            return NativeInteractiveMessageAlertController(
                titleText: message.title,
                messageText: text,
                imageURL: nil,
                image: image,
                category: category,
                actionHandler: {
                    action in
                    MobileMessaging.handleAction(
                        identifier: action.identifier,
                        category: categoryId,
                        message: self.message,
                        notificationUserInfo: self.message.originalPayload,
                        userText: nil,
                        completionHandler: {}
                    )
            })
        } else {
            return NativeInteractiveMessageAlertController(
                titleText: message.title,
                messageText: text,
                imageURL: nil,
                image: image,
                dismissTitle: message.inAppDismissTitle,
                openTitle: message.inAppOpenTitle,
                actionHandler: {
                    action in
                    MobileMessaging.handleAction(
                        identifier: action.identifier,
                        category: nil,
                        message: self.message,
                        notificationUserInfo: self.message.originalPayload,
                        userText: nil,
                        completionHandler: {}
                    )
                })
        }
    }
}
