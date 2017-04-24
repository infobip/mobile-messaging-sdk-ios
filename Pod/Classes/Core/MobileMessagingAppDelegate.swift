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
open class MobileMessagingAppDelegate: UIResponder, UIApplicationDelegate {
	
	/// Defines whether the Geofencing service is enabled.
	///
	/// Default value is `false` (The service is disabled by default). If you want to enable the Geofencing service you override this variable in your application delegate (the one you inherit from `MobileMessagingAppDelegate`) and return `true`.
	@available(*, unavailable, message: "Please use `MobileMessaging.geofencingService.start(completion:)` or `MobileMessaging.withApplicationCode(:notificationType:).withGeofencing().start(:)` in order to enable and start Geofencing services features.")
	open var geofencingServiceEnabled: Bool {
		return false
	}
	
	/// Passes your Application Code to the Mobile Messaging SDK.
	///
	/// In order to provide your own unique Application Code, you override this variable in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
	open var applicationCode: String {
		fatalError("Application code not set. Please override `applicationCode` variable in your subclass of `MobileMessagingAppDelegate`.")
	}
	
	/// Preferable notification types that indicating how the app alerts the user when a push notification arrives.
	/// 
	/// You should override this variable in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
	/// - remark: For now, Mobile Messaging SDK doesn't support badge. You should handle the badge counter by yourself.
	open var userNotificationType: UIUserNotificationType {
		fatalError("UserNotificationType not set. Please override `userNotificationType` variable in your subclass of `MobileMessagingAppDelegate`.")
	}
	
	//MARK: Public
	public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
		if !isTestingProcessRunning {
			let session = MobileMessaging.withApplicationCode(applicationCode, notificationType: userNotificationType)
			session?.start()
		}
		return mm_application(application, didFinishLaunchingWithOptions: launchOptions)
	}
	
	public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		if !isTestingProcessRunning {
			MobileMessaging.didRegisterForRemoteNotificationsWithDeviceToken(deviceToken)
		}
		mm_application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
	}
	
	public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		if !isTestingProcessRunning {
			MobileMessaging.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: { result in
				completionHandler(result)
			})
		}
		mm_application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
	}

	public func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
		if !isTestingProcessRunning {
			MobileMessaging.didReceiveLocalNotification(notification)
		}
		mm_application(application, didReceiveLocalNotification: notification)
	}
	
	/// This is a substitution for the standard `application(:didFinishLaunchingWithOptions:)`.
	///
	/// You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the launch process is almost done and the app is almost ready to run.
	@nonobjc open func mm_application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]?) -> Bool {
		return true
	}
	
	/// This is a substitution for the standard `application(:didRegisterForRemoteNotificationsWithDeviceToken:)`.
	///
	/// You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the app successfully registered with Apple Push Notification service (APNs).
	@nonobjc open func mm_application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
		// override this callback in your AppDelegate if needed
	}
	
	/// This is a substitution for the standard `application(:didReceiveRemoteNotification:fetchCompletionHandler:)`.
	///
	/// You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when a remote notification arrived that indicates there is data to be fetched.
	@nonobjc open func mm_application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
		// override this callback in your AppDelegate if needed
	}
	
	/// This is a substitution for the standard `application(:didReceiveLocalNotification:)`.
	///
	/// You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the running app receives a local notification.
	@nonobjc open func mm_application(_ application: UIApplication, didReceiveLocalNotification n: UILocalNotification) {
		// override this callback in your AppDelegate if needed
	}
}
