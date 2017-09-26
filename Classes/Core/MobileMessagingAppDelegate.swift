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
		
	/// Passes your Application Code to the Mobile Messaging SDK.
	///
	/// In order to provide your own unique Application Code, you override this variable in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
	open var applicationCode: String {
		fatalError("Application code not set. Please override `applicationCode` variable in your subclass of `MobileMessagingAppDelegate`.")
	}
	
	open var appGroupId: String? {
		return nil
	}
	
	/// Preferable notification types that indicating how the app alerts the user when a push notification arrives.
	/// 
	/// You should override this variable in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
	/// - remark: For now, Mobile Messaging SDK doesn't support badge. You should handle the badge counter by yourself.
	open var userNotificationType: UserNotificationType {
		fatalError("UserNotificationType not set. Please override `userNotificationType` variable in your subclass of `MobileMessagingAppDelegate`.")
	}
	
	/// Set of categories that indicating which buttons will be displayed and behavour of these buttons when a push notification arrives.
	///
	/// You can override this variable in your application delegate, that you inherit from `MobileMessagingAppDelegate`.
	/// Once application started, provided categories will be registered.
	/// - remark: Mobile Messaging SDK reserves category Ids and action Ids with "mm_" prefix. Custom actions and categories with this prefix will be discarded.
	open var interactiveNotificationCategories: Set<NotificationCategory>? {
		return nil
	}
	
	//MARK: Public
	public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
		if !isTestingProcessRunning {
			var session = MobileMessaging.withApplicationCode(applicationCode, notificationType: userNotificationType)
			
			if #available(iOS 10.0, *) {
				if let appGroupId = appGroupId {
					session = session?.withAppGroupId(appGroupId)
				}
			}
			
			if let categories = interactiveNotificationCategories {
				session = session?.withInteractiveNotificationCategories(categories)
			}
			
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

	public func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, completionHandler: @escaping () -> Void) {
		if UIDevice.current.IS_IOS_BEFORE_10 && !isTestingProcessRunning {
			MobileMessaging.handleActionWithIdentifier(identifier: identifier, localNotification: notification, responseInfo: nil, completionHandler: completionHandler)
		}
        mm_application(application, handleActionWithIdentifier: identifier, for: notification, withResponseInfo: nil, completionHandler: completionHandler)
	}
	
	public func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {
		if UIDevice.current.IS_IOS_BEFORE_10 && !isTestingProcessRunning {
			MobileMessaging.handleActionWithIdentifier(identifier: identifier, forRemoteNotification: userInfo, responseInfo: nil, completionHandler: completionHandler)
		}
		mm_application(application, handleActionWithIdentifier: identifier, forRemoteNotification: userInfo, withResponseInfo: nil, completionHandler: completionHandler)
	}

	public func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, withResponseInfo responseInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {
		if UIDevice.current.IS_IOS_BEFORE_10 && !isTestingProcessRunning {
			MobileMessaging.handleActionWithIdentifier(identifier: identifier, localNotification: notification, responseInfo: responseInfo, completionHandler: completionHandler)
        }
        mm_application(application, handleActionWithIdentifier: identifier, for: notification, withResponseInfo: responseInfo, completionHandler: completionHandler)
    }
    
    public func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable : Any], withResponseInfo responseInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {
		if UIDevice.current.IS_IOS_BEFORE_10 && !isTestingProcessRunning {
			MobileMessaging.handleActionWithIdentifier(identifier: identifier, forRemoteNotification: userInfo, responseInfo: responseInfo, completionHandler: completionHandler)
        }
        mm_application(application, handleActionWithIdentifier: identifier, forRemoteNotification: userInfo, withResponseInfo: responseInfo, completionHandler: completionHandler)
    }
	
	/// This is substitution for standart `application(:handleActionWithIdentifier:for:completionHandler)`
	///
	/// You can override this method in your own application delegate in case you have choosen th Application Delegate inheritance way to integrate with Mobile Messaging SDK.
	
	@nonobjc public func mm_application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, withResponseInfo responseInfo: [AnyHashable : Any]?,completionHandler: @escaping () -> Void) {
		// override this callback in your AppDelegate if needed
	}
	
	/// This is substitution for standart `application(:handleActionWithIdentifier:handleActionWithIdentifier:completionHandler)`
	///
	/// You can override this method in your own application delegate in case you have choosen th Application Delegate inheritance way to integrate with Mobile Messaging SDK.
	@nonobjc public func mm_application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable : Any], withResponseInfo responseInfo: [AnyHashable : Any]?, completionHandler: @escaping () -> Void) {
		// override this callback in your AppDelegate if needed
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
	@nonobjc open func mm_application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		// override this callback in your AppDelegate if needed
	}
	
	/// This is a substitution for the standard `application(:didReceiveLocalNotification:)`.
	///
	/// You override this method in your own application delegate in case you have chosen the Application Delegate inheritance way to integrate with Mobile Messaging SDK and you have some work to be done when the running app receives a local notification.
	@nonobjc open func mm_application(_ application: UIApplication, didReceiveLocalNotification n: UILocalNotification) {
		// override this callback in your AppDelegate if needed
	}
}
