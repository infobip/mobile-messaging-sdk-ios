/// Implementation of `InAppMessagePresenter` which shows an old-style in-app message as a native popup. Preloaded resource is an image.
class NativeInAppMessagePresenter: NamedLogger, InAppMessagePresenter {
    typealias Resources = Image
    private let message: MM_MTMessage
    private let text: String
    unowned var delegate: InAppMessagePresenterDelegate
    var messageController: InteractiveMessageAlertController?
    
    init(forMessage message: MM_MTMessage, text: String, withDelegate delegate: InAppMessagePresenterDelegate) {
        self.message = message
        self.text = text
        self.delegate = delegate
    }
    
    func loadResources(completion completionHandler: @escaping (Resources?) -> Void) {
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

    func createMessageController(withResources image: Resources?) -> InteractiveMessageAlertController? {
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
