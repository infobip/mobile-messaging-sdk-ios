//
//  AppDelegate.swift
//  MobileMessaging
//
//  Created by Andrey K. on 03/29/2016.

import UIKit
import MobileMessaging
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	
	var window: UIWindow?
	
	func applicationDidFinishLaunching(_ application: UIApplication) {
		MobileMessaging
			.withApplicationCode(
				"<# your application code #>",
				notificationType: UserNotificationType(options: [.alert, .sound]))?
			.withInteractiveNotificationCategories(customCategories)
			.start()
		setupLogging()
		UIToolbar.setupAppearance()
	}
	
	func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
	}
	
	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
	}
	
	func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
		MobileMessaging.didReceiveLocalNotification(notification)
	}
	
	func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, completionHandler: @escaping () -> Void) {
		MobileMessaging.handleActionWithIdentifier(identifier: identifier, localNotification: notification, responseInfo: nil, completionHandler: completionHandler)
	}
	
	func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {
		MobileMessaging.handleActionWithIdentifier(identifier: identifier, forRemoteNotification: userInfo, responseInfo: nil, completionHandler: completionHandler)
	}
	
	func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, withResponseInfo responseInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {
		MobileMessaging.handleActionWithIdentifier(identifier: identifier, localNotification: notification, responseInfo: responseInfo, completionHandler: completionHandler)
	}
	
	func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable : Any], withResponseInfo responseInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {
		MobileMessaging.handleActionWithIdentifier(identifier: identifier, forRemoteNotification: userInfo, responseInfo: responseInfo, completionHandler: completionHandler)
	}
	
	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
		return LinksHandler.openDeeplink(url: url, withMessage: nil)
	}
}
