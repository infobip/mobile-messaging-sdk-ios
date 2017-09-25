//
//  AppDelegate.swift
//  MobileMessaging
//
//  Created by Andrey K. on 03/29/2016.

import UIKit
import MobileMessaging
import UserNotifications

@UIApplicationMain
class AppDelegate: MobileMessagingAppDelegate {
	
	var window: UIWindow?
	
	override var appGroupId: String { return "group.com.mobile-messaging.notification-service-extension" }
	
	override var applicationCode: String { return "<# your application code #>" }
	
	override var userNotificationType: UserNotificationType { return UserNotificationType(options: [.alert, .sound]) }
	
	override func mm_application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		setupLogging()
		MobileMessaging.notificationActionHandler = CustomActionHandler()
		UIToolbar.setupAppearance()
		return true
	}
	
	func setupLogging() {
		MobileMessaging.logger?.logOutput = MMLogOutput.Console
		MobileMessaging.logger?.logLevel = .All
	}
	
	override var interactiveNotificationCategories: Set<NotificationCategory>? {
		return customCategories
	}
	
	func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
		return LinksHandler.openDeeplink(url: url, withMessage: nil)
	}
}
