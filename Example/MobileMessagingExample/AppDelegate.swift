//
//  AppDelegate.swift
//  MobileMessaging
//
//  Created by Andrey K. on 03/29/2016.

import UIKit
import MobileMessaging

@UIApplicationMain
class AppDelegate: MobileMessagingAppDelegate {
	
	var window: UIWindow?
	
	override var applicationCode: String { return "40b4ba5a62004d8a80ee3bb49cbaf077-50f69373-f84f-466c-830f-fcdb7d15a6bd" }
	
	override var userNotificationType: UIUserNotificationType { return [.Alert, .Sound] }
	
	override func mm_application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		setupLogging()
		return true
	}
	
	func setupLogging() {
		if let loggingUtil = MobileMessaging.loggingUtil {
			loggingUtil.setLoggingOptions([MMLoggingOptions.Console], logLevel: .All)
		}
	}
}


