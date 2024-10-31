//  NotificationService.swift

import UserNotifications
import MobileMessaging

class NotificationService: UNNotificationServiceExtension {

	var contentHandler: ((UNNotificationContent) -> Void)?
	var originalContent: UNNotificationContent?

	override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
		self.contentHandler = contentHandler
		self.originalContent = request.content

        let mutableContent: UNMutableNotificationContent? = (request.content.mutableCopy() as? UNMutableNotificationContent)
        mutableContent?.badge = NSNumber(value: handleBadgeCount())

        if MM_MTMessage.isCorrectPayload(request.content.userInfo) {
            MobileMessagingNotificationServiceExtension.startWithApplicationCode("<# your mobile application code #>")
            MobileMessagingNotificationServiceExtension.didReceive(
                content: localisedContentFor(mutableContent ?? request.content),
                withContentHandler: contentHandler)
        } else {
                // handling by another push provider different than Infobip's
        }
	}

	override func serviceExtensionTimeWillExpire() {
		MobileMessagingNotificationServiceExtension.serviceExtensionTimeWillExpire()
		if let originalContent = originalContent {
			contentHandler?(originalContent)
		}
	}

    private func handleBadgeCount() -> Int {
        var badgeNumber = UserDefaults.standard.integer(forKey: "ChatExampleBadgeNumber")
        badgeNumber += 1
        UserDefaults.standard.set(badgeNumber, forKey: "ChatExampleBadgeNumber")

        if #available(iOS 16.0, *) {
             UNUserNotificationCenter.current().requestAuthorization(options: .badge) { (authorised, error) in
                 guard authorised, error == nil else { return }
                 UNUserNotificationCenter.current().setBadgeCount(
                    badgeNumber > 0 ? badgeNumber : 0, withCompletionHandler: { _ in
                        /*  Do nothing, recoverable error */
                    }) }
        } else {
            /*
             You cannot alter the badge number within a UNNotificationServiceExtension in older iOS versions.
             Only options is to listen to incoming push notification and apply the counting in the parent app (it will work if it is in background, but badge count won't be updated if the app is killed)
             */
        }
        return badgeNumber
    }

    private func localisedContentFor(_ content: UNNotificationContent) -> UNNotificationContent {
        guard let contentToModify = content.mutableCopy() as? UNMutableNotificationContent else {
            return content
        }
        let doEditPushContent = true
        if doEditPushContent {
            contentToModify.title = "New notification arrived!"
            contentToModify.body = "The content is: \(contentToModify.body)"
        }
        return contentToModify
    }
}
