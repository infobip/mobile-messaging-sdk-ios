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
	
	override var userNotificationType: UIUserNotificationType { return [.alert, .sound] }
	
	override func mm_application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool {
		setupLogging()
		return true
	}
	
	func setupLogging() {
		MobileMessaging.logger.logOutput = MMLogOutput.Console
		MobileMessaging.logger.logLevel = .All
		
		
		MobileMessaging.notificationTapHandler = { message in
			print("Dish is \(message.customPayload?["dish"] as? String)")
			print("URL is \(message.customPayload?["url"] as? String)")
		}
	}
}


