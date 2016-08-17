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

	override var applicationCode: String { return "a2277b20b0d4193998f10f06ab1f451f-2d951329-a751-41ae-b215-b7ceab09f9a0" }
	
	override var userNotificationType: UIUserNotificationType { return [.Alert, .Sound] }
	
	override func mm_application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		setupLogging()
		return true
	}
	
	func setupLogging() {
		MobileMessaging.loggingUtil.setLoggingOptions([MMLoggingOptions.Console], logLevel: .All)
	}
}


