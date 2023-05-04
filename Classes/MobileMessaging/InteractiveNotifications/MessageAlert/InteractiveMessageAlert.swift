 //
//  InteractiveMessageAlert.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 23/04/2018.
//

import Foundation
import UserNotifications
import UIKit

@objc protocol InAppAlertDelegate {
	func willDisplay(_ message: MM_MTMessage)
}

@objcMembers
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

    func showModalNotificationManually(forMessage message: MM_MTMessage) {
        guard !message.isGeoSignalingMessage else {
            logDebug("Geo signaling message cannot be displayed with in-app")
            return
        }
        logDebug("Displaying modal in-app manually")
        showModalNotification(forMessage: message, exclusively: false)
    }
    
    func showModalNotificationAutomatically(forMessage message: MM_MTMessage) {
		guard let inAppStyle = message.inAppStyle, shouldShowInAppNotification(forMessage: message) else {
			return
		}

		switch inAppStyle {
		case .Banner:
			break
		case .Modal:
            if (MobileMessaging.messageHandlingDelegate?.shouldShowModalInAppNotification?(for: message) ?? true) {
                logDebug("Displaying modal in-app automatically")
                showModalNotification(forMessage: message, exclusively: MobileMessaging.application.applicationState == .background)
            } else {
                logDebug("Modal notification for message: \(message.messageId) text: \(message.text.orNil) is disabled by MMMessageHandlingDelegate")
            }
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
		logDebug("Alert for message will be shown: \(message.messageId) text: \(message.text.orNil)")

		if exclusively {
			cancelAllAlerts()
		}
        AlertQueue.sharedInstace.enqueueAlert(message: message, text: message.text ?? "")
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
