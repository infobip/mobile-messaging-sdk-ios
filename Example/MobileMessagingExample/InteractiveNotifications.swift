//
//  InteractiveNotifications.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 24.08.17.
//

import Foundation
import MobileMessaging

extension AppDelegate {
	func setupLogging() {
		MobileMessaging.logger?.logOutput = MMLogOutput.Console
		MobileMessaging.logger?.logLevel = .Debug
	}
	
	var customCategories: Set<MMNotificationCategory> {
		var categories = Set<MMNotificationCategory>()
		categories.insert(categoryShareCancel)
		if let _replyCategory = replyCategory {
			categories.insert(_replyCategory)
		}
		return categories
	}
	
	var categoryShareCancel: MMNotificationCategory {
		//Action with title "Cancel", which will be marked as destructive and will require device to be unlocked before proceed
		let cancelAction = MMNotificationAction(identifier: "cancel",
											  title: "Cancel",
											  options: [.destructive, .authenticationRequired])!
		//Action with title "Share", which will require device to be unlocked before proceed and will bring application to the foreground
		let shareAction = MMNotificationAction(identifier: "share",
											 title: "Share",
											 options: [.foreground, .authenticationRequired])!
		
		let category = MMNotificationCategory(identifier: "category_share_cancel",
											actions: [shareAction, cancelAction],
											options: nil,
											intentIdentifiers: nil)
		return category!
	}
	
	var replyCategory: MMNotificationCategory? {
		if let replyAction = MMTextInputNotificationAction(identifier: "reply", title: "Reply", options: [], textInputActionButtonTitle: "Reply", textInputPlaceholder: "print reply here") {
			return MMNotificationCategory(identifier: "category_reply",
										actions: [replyAction],
										options: nil,
										intentIdentifiers: nil)
		} else {
			return nil
		}
	}
}
