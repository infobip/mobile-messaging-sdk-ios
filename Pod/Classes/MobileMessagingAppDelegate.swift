//
//  MobileMessagingAppDelegate.swift
//  Pods
//
//  Created by Andrey K. on 12/04/16.
//
//

import Foundation

/**
The Application Delegate inheritance - is a way to integrate Mobile Messaging SDK into your application.
To implement this way, you should inherit your Application Delegate from `MobileMessagingAppDelegate`.
*/
public class MobileMessagingAppDelegate: UIResponder, UIApplicationDelegate {
	/**
	Passes your Application Code to the Mobile Messaging SDK. In order to provide your own unique Application Code, you override this variable in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
	*/
	public var applicationCode: String {
		fatalError("Application code not set. Please override `applicationCode` variable in your subclass of `MobileMessagingAppDelegate`.")
	}
	
	/**
	Passes your preferable notification types to the Mobile Messaging SDK. You should override this variable in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
	- remark: For now, Mobile Messaging SDK doesn't support badge. You should handle the badge counter by yourself.
	*/
	public var userNotificationType: UIUserNotificationType {
		fatalError("UserNotificationType not set. Please override `userNotificationType` variable in your subclass of `MobileMessagingAppDelegate`.")
	}
	
	//MARK: Public
	final public func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		MobileMessaging.startWithApplicationCode(applicationCode)
		registerRemoteNotifications(application)
		return mm_application(application, didFinishLaunchingWithOptions: launchOptions)
	}
	
	final public func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
		MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
		mm_application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
	}
	
	final public func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
		mm_application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
	}
	
	/**
	This is a substitution for the standard `application(:didFinishLaunchingWithOptions:)`.
	You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the launch process is almost done and the app is almost ready to run.
	*/
	public func mm_application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		return true
	}
	
	/**
	This is a substitution for the standard `application(:didRegisterForRemoteNotificationsWithDeviceToken:)`.
	You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the app successfully registered with Apple Push Notification service (APNs).
	*/
	public func mm_application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) { }
	
	/**
	This is an substitution for the standard `application(:didReceiveRemoteNotification:fetchCompletionHandler:)`.
	You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when a remote notification arrived that indicates there is data to be fetched.
	*/
	public func mm_application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) { }
	
	//MARK: Private
	private func registerRemoteNotifications(application: UIApplication) {
		application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: userNotificationType, categories: nil))
		application.registerForRemoteNotifications()	
	}
}