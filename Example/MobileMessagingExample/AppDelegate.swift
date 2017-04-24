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
	
	override var applicationCode: String { return "<# your application code #>" }
	
	override var userNotificationType: UIUserNotificationType { return [.alert, .sound] }
		
	override func mm_application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool {
		setupLogging()
		return true
	}
	
	func setupLogging() {
		MobileMessaging.logger?.logOutput = MMLogOutput.Console
		MobileMessaging.logger?.logLevel = .All
	}
}
