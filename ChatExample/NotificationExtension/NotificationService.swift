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
        mutableContent?.badge = NSNumber(value: BadgeCounterHandler.increaseBadge(by: 1))

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
