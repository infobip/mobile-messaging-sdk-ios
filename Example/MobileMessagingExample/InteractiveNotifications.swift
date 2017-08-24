//
//  InteractiveNotifications.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 24.08.17.
//

import Foundation
import MobileMessaging

extension AppDelegate {
	var customCategories: Set<NotificationCategory>? {
		//Action with title "Cancel", which will be marked as destructive and will require device to be unlocked before proceed
		let cancelAction = NotificationAction(identifier: "cancel",
		                                      title: "Cancel",
		                                      options: [.destructive, .authenticationRequired])
		//Action with title "Share", which will require device to be unlocked before proceed and will bring application to the foreground
		let shareAction = NotificationAction(identifier: "share",
		                                     title: "Share",
		                                     options: [.foreground, .authenticationRequired])
		
		
		guard let _cancelAction = cancelAction,
			let _shareAction = shareAction else {
				return nil
		}
		let category: NotificationCategory?
		if #available(iOS 10.0, *) {
			category = NotificationCategory(identifier: "category_share_cancel",
			                                actions: [_shareAction, _cancelAction],
			                                options: [.customDismissAction],
			                                intentIdentifiers: nil)
		} else {
			category = NotificationCategory(identifier: "category_share_cancel",
			                                actions: [_shareAction, _cancelAction],
			                                options: nil,
			                                intentIdentifiers: nil)
		}
		
		guard let _category = category else {
			return nil
		}
		return [_category]
	}
}

class CustomActionHandler: NotificationActionHandling {
	func handle(action: NotificationAction, forMessage message: MTMessage, withCompletionHandler completionHandler: @escaping () -> Void) {
		print(action.identifier)
		completionHandler()
	}
}
