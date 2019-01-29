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
		if !ProcessInfo.processInfo.arguments.contains("-IsStartedToRunTests") {
			setupLogging()
			MobileMessaging
			.withApplicationCode(
				"3c59f6e341a6896fc05b8cd7e3f3fdf8-031a75db-fd8f-46b0-9f2b-a2e915d7b952_",
				notificationType: UserNotificationType(options: [.alert, .sound]))?
			.withInteractiveNotificationCategories(customCategories)
			.start()
		}
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
