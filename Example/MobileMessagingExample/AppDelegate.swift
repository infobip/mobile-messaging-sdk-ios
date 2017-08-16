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
	
	override var appGroupId: String { return "group.com.mobile-messaging.notification-service-extension" }
	
	override var applicationCode: String { return "<# your application code #>" }
	
	override var userNotificationType: UIUserNotificationType { return [.alert, .sound] }
		
	override func mm_application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		setupLogging()
        
        UIToolbar.appearance().barTintColor = UIColor(red: 0xF0 / 255.0,
                                                      green: 0x7D / 255.0,
                                                      blue: 0x15 / 255.0,
                                                      alpha: 1.0)
        UIToolbar.appearance().tintColor = UIColor.white
        
		return true
	}
	
	func setupLogging() {
		MobileMessaging.logger?.logOutput = MMLogOutput.Console
		MobileMessaging.logger?.logLevel = .All
	}
}
