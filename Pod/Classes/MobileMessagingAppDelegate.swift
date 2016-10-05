//
//  MobileMessagingAppDelegate.swift
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
	
	/// Defines whether the Geofencing service is enabled.
	///
	/// Default value is `false` (The service is disabled by default). If you want to enable the Geofencing service you override this variable in your application delegate (the one you inherit from `MobileMessagingAppDelegate`) and return `true`.
	public var geofencingServiceEnabled: Bool {
		return false
	}
	
	/// Passes your Application Code to the Mobile Messaging SDK.
	///
	/// In order to provide your own unique Application Code, you override this variable in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
	public var applicationCode: String {
		fatalError("Application code not set. Please override `applicationCode` variable in your subclass of `MobileMessagingAppDelegate`.")
	}
	
	/// Preferable notification types that indicating how the app alerts the user when a push notification arrives.
	/// 
	/// You should override this variable in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
	/// - remark: For now, Mobile Messaging SDK doesn't support badge. You should handle the badge counter by yourself.
	public var userNotificationType: UIUserNotificationType {
		fatalError("UserNotificationType not set. Please override `userNotificationType` variable in your subclass of `MobileMessagingAppDelegate`.")
	}
	
	//MARK: Public
	final public func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		if !isTesting {
			var session = MobileMessaging.withApplicationCode(applicationCode, notificationType: userNotificationType)
			if geofencingServiceEnabled {
				session = session.withGeofencingService()
			}
			session.start()
		}
		return mm_application(application, didFinishLaunchingWithOptions: launchOptions)
	}
	
	final public func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
		if !isTesting {
			MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
		}
		mm_application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
	}
	
	final public func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		if !isTesting {
			MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
		}
		mm_application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
	}
	
	/// This is a substitution for the standard `application(:didFinishLaunchingWithOptions:)`.
	///
	/// You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the launch process is almost done and the app is almost ready to run.
	public func mm_application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
		return true
	}
	
	/// This is a substitution for the standard `application(:didRegisterForRemoteNotificationsWithDeviceToken:)`.
	///
	/// You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the app successfully registered with Apple Push Notification service (APNs).
	public func mm_application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
		// override this callback in your AppDelegate if needed
	}
	
	/// This is a substitution for the standard `application(:didReceiveRemoteNotification:fetchCompletionHandler:)`.
	///
	/// You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when a remote notification arrived that indicates there is data to be fetched.
	public func mm_application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		// override this callback in your AppDelegate if needed
	}
	
	//MARK: Private
	private var isTesting: Bool {
		return NSProcessInfo.processInfo().arguments.contains("-IsDeviceStartedToRunTests")
	}
}
