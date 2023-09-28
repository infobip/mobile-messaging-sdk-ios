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

@objcMembers
public class MMInteractiveMessageAlertSettings: NSObject {
	public static var errorPlaceholderText: String = "Sorry, couldn't load the image"
	public static var tintColor = UIColor(red: 0, green: 122, blue: 255, alpha: 1)
	public static var enabled: Bool = true
    ///cornerRadius is only supported for webInApps
    public static var cornerRadius: Float = 16.0
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
        guard areGeneralConditionsForShowingInAppMessageSatisfied(message) else { return }
        
        if (message as? MMInAppMessage) == nil { // is old-style in-app message
            guard areConditionsForShowingOldStyleInAppMessageSatified(message), message.inAppStyle == .Modal else {
                return
            }
        }
        
        if (MobileMessaging.messageHandlingDelegate?.shouldShowModalInAppNotification?(for: message) ?? true) {
            logDebug("Displaying modal in-app automatically")
            showModalNotification(forMessage: message, exclusively: MobileMessaging.application.applicationState == .background)
        } else {
            logDebug("Modal notification for message: \(message.messageId) text: \(message.text.orNil) is disabled by MMMessageHandlingDelegate")
        }
	}

    func showBannerNotificationIfNeeded(forMessage message: MM_MTMessage?,
                                        showBannerWithOptions: @escaping (UNNotificationPresentationOptions) -> Void) {
        if let handlingSubservice = MobileMessaging.sharedInstance?.subservices.values.first(where: { $0.handlesInAppNotification(forMessage: message)}) {
            handlingSubservice.showBannerNotificationIfNeeded(forMessage: message, showBannerWithOptions: showBannerWithOptions)
            return
        }
        
        guard let message,
              areGeneralConditionsForShowingInAppMessageSatisfied(message),
              (message as? MMInAppMessage) == nil, // is old-style in-app message
              areConditionsForShowingOldStyleInAppMessageSatified(message),
              message.inAppStyle == .Banner
        else {
            return showBannerWithOptions([])
        }
        
        showBannerWithOptions(InteractiveMessageAlertManager.presentationOptions(for: message))
	}
    
    /// Performs specific checks whether old-style `MM_MTMessage` can be shown.
    private func areConditionsForShowingOldStyleInAppMessageSatified(_ message: MM_MTMessage) -> Bool {
        message.inAppStyle != nil
    }
    
    /// Performs general checks whether `MM_MTMessage` can be shown regardless of whether it's new-style or old-style.
    private func areGeneralConditionsForShowingInAppMessageSatisfied(_ message: MM_MTMessage) -> Bool {
        guard MMInteractiveMessageAlertSettings.enabled else { return false }
        guard !message.isExpired else { return false }
        
        let noActionPerformed = (message.category != nil && message.appliedAction?.identifier == MMNotificationAction.DefaultActionId) || message.appliedAction == nil
        guard noActionPerformed else { return false }
        
        return !message.isGeoSignalingMessage
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
