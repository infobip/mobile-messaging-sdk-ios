//
//  AppDelegate.swift
//  MobileChatExample
//
//  Created by Andrey Kadochnikov on 10/11/2017.
//  Copyright © 2017 Infobip d.o.o. All rights reserved.
//
//

import UIKit
import MobileMessaging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		MobileMessaging.withApplicationCode("<# your application code #>", notificationType: .alert)?.withInAppChat().start()
		MobileMessaging.logger?.logLevel = .All
		MobileMessaging.logger?.logOutput = .Console
		return true
	}

	func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
	}
	
	func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
	}
}
