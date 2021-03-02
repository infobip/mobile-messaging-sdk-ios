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
                "<# your application code #>",
				notificationType: MMUserNotificationType(options: [.alert, .sound]))?
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

	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
		return LinksHandler.openDeeplink(url: url, withMessage: nil)
	}
}
