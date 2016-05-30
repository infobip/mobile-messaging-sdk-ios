//
//  AppDelegate.swift
//  MobileMessaging
//
//  Created by Andrey K. on 03/29/2016.

import UIKit
import MobileMessaging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	
	var window: UIWindow?
	
	var isTesting: Bool {
		return NSProcessInfo.processInfo().arguments.contains("-IsDeviceStartedToRunTests")
	}
	
	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {
		if !isTesting {
			MobileMessaging.startWithApplicationCode([.Alert, .Sound], applicationCode: "40b4ba5a62004d8a80ee3bb49cbaf077-50f69373-f84f-466c-830f-fcdb7d15a6bd")
			setupLogging()
		}
		return true
	}

	func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
	}
	
	func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
		MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
	}
	
	func setupLogging() {
		if let loggingUtil = MobileMessaging.loggingUtil {
			loggingUtil.setLoggingOptions([MMLoggingOptions.Console], logLevel: .All)
		}
	}
}


