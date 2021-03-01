 //
//  InteractiveMessageAlert.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 23/04/2018.
//

import Foundation
import UserNotifications

@objc protocol InAppAlertDelegate {
	func willDisplay(_ message: MM_MTMessage)
}

public class MMInteractiveMessageAlertSettings: NSObject {
	public static var errorPlaceholderText: String = "Sorry, couldn't load the image"
	public static var tintColor = UIColor(red: 0, green: 122, blue: 255, alpha: 1)
	public static var enabled: Bool = true
}

class InteractiveMessageAlertManager: NamedLogger {
	static let sharedInstance = InteractiveMessageAlertManager()
	var delegate: InAppAlertDelegate?

	func cancelAllAlerts() {
		AlertQueue.sharedInstace.cancelAllAlerts()
	}

	func showModalNotificationIfNeeded(forMessage message: MM_MTMessage) {
		guard let inAppStyle = message.inAppStyle else {
			return
		}

		switch inAppStyle {
		case .Banner:
			break
		case .Modal:
			showModalNotification(forMessage: message, exclusively: MobileMessaging.application.applicationState == .background)
		}
	}

	func showBannerNotificationIfNeeded(forMessage message: MM_MTMessage?, showBannerWithOptions: @escaping (UNNotificationPresentationOptions) -> Void) {
		
		if let handlingSubservice = MobileMessaging.sharedInstance?.subservices.values.first(where: { $0.handlesInAppNotification(forMessage: message)}) {
			handlingSubservice.showBannerNotificationIfNeeded(forMessage: message, showBannerWithOptions: showBannerWithOptions)
			return
		}
				
		guard let message = message, let inAppStyle = message.inAppStyle, shouldShowInAppNotification(forMessage: message) else {
			showBannerWithOptions([])
			return
		}

		switch inAppStyle {
		case .Banner:
			showBannerWithOptions(InteractiveMessageAlertManager.presentationOptions(for: message))
		case .Modal:
			break
		}
	}

	private func shouldShowInAppNotification(forMessage message: MM_MTMessage) -> Bool {
		let enabled = MMInteractiveMessageAlertSettings.enabled
		let notExpired = !message.isExpired
		let noActionPerformed = (message.category != nil && message.appliedAction?.identifier == MMNotificationAction.DefaultActionId) || message.appliedAction == nil
		let inAppRequired = message.inAppStyle != nil
        return enabled && notExpired && inAppRequired && noActionPerformed && !message.isGeoSignalingMessage
	}

	private func showModalNotification(forMessage message: MM_MTMessage, exclusively: Bool) {
		guard shouldShowInAppNotification(forMessage: message), let text = message.text else {
			return
		}

		logDebug("Alert for message will be shown: \(message.messageId) text: \(message.text.orNil)")

		if exclusively {
			cancelAllAlerts()
		}
		AlertQueue.sharedInstace.enqueueAlert(message: message, text: text)
	}

	static func presentationOptions(for message: MM_MTMessage?) -> UNNotificationPresentationOptions {
		let ret: UNNotificationPresentationOptions

		if let msg = message, msg.inAppStyle == .Banner {
			ret = UNNotificationPresentationOptions.make(with:  MobileMessaging.sharedInstance?.userNotificationType ?? [])
		} else {
			ret = []
		}
		return ret
	}
}
