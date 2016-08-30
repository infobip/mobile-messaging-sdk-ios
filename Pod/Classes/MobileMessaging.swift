//
//  MobileMessaging.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//
//

import Foundation

public final class MobileMessaging: NSObject {
	
	static var sharedInstance: MobileMessaging?
	let userNotificationType: UIUserNotificationType,
		applicationCode: String
	
	var	storageType: MMStorageType = .SQLite,
		remoteAPIBaseURL: String = MMAPIValues.kProdBaseURLString,
		geofencingServiceDisabled: Bool = false
	
	private init(applicationCode: String, notificationType: UIUserNotificationType) {
		self.applicationCode = applicationCode
		self.userNotificationType = notificationType
	}
	
	//MARK: Public
	public class func withApplicationCode(_ code: String, notificationType: UIUserNotificationType) -> MobileMessaging {
		sharedInstance = MobileMessaging(applicationCode: code, notificationType: notificationType)
		return sharedInstance!
	}
	
	public func withBackendBaseURL(_ urlString: String) -> MobileMessaging {
		remoteAPIBaseURL = urlString
		return self
	}
	
	public func withGeofencingServiceDisabled(_ disabled: Bool) -> MobileMessaging {
		geofencingServiceDisabled = disabled
		return self
	}
	
	/**
	Starts a new Mobile Messaging session. This method should be called form AppDelegate's `application(_:didFinishLaunchingWithOptions:)` callback.
	- remark: For now, Mobile Messaging SDK doesn't support badge. You should handle the badge counter by yourself.
	- parameter userNotificationType: Preferable notification types that indicating how the app alerts the user when a  push notification arrives.
	- parameter applicationCode: The application code of your Application from Push Portal website.
	- parameter backendBaseURL: Your backend server base URL, optional parameter. Default is http://oneapi.infobip.com.
	*/
	public func start(_ completion: ((Void) -> Void)? = nil) {
		MMLogDebug("Starting MobileMessaging service...")
		MobileMessaging.singletonQueue.executeAsync {
			do {
				var storage: MMCoreDataStorage?
				switch self.storageType {
				case .InMemory:
					storage = try MMCoreDataStorage.newInMemoryStorage()
				case .SQLite:
					storage = try MMCoreDataStorage.SQLiteStorage()
				}
				if let storage = storage {
					self.storage = storage
					let installation = MMInstallation(storage: storage, baseURL: self.remoteAPIBaseURL, applicationCode: self.applicationCode)
					self.currentInstallation = installation
					let user = MMUser(installation: installation)
					self.currentUser = user
					let messageHandler = MMMessageHandler(storage: storage, baseURL: self.remoteAPIBaseURL, applicationCode: self.applicationCode)
					self.messageHandler = messageHandler
					self.appListener = MMApplicationListener(messageHandler: messageHandler, installation: installation, user: user)
					
					if !self.geofencingServiceDisabled {
						MMGeofencingService.sharedInstance.start()
					}
					
					MMLogInfo("MobileMessaging SDK service successfully initialized.")
				}
			} catch {
				MMLogError("Unable to initialize Core Data stack. MobileMessaging SDK service stopped because of the fatal error.")
			}

			if UIApplication.shared.isRegisteredForRemoteNotifications && self.currentInstallation?.deviceToken == nil {
				MMLogDebug("The application is registered for remote notifications but MobileMessaging lacks of device token. Unregistering...")
				UIApplication.shared.unregisterForRemoteNotifications()
			}
			
			let categories = MMNotificationCategoryManager.categoriesToRegister()
			UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: self.userNotificationType, categories: categories))
			if UIApplication.shared.isRegisteredForRemoteNotifications == false {
				MMLogDebug("Registering for remote notifications...")
				UIApplication.shared.registerForRemoteNotifications()
			}
		}
	}
	
	/**
	Stops current Mobile Messaging session.
	*/
	public class func stop(_ cleanUpData: Bool = false) {
		if cleanUpData {
			MobileMessaging.sharedInstance?.cleanUpAndStop()
		} else {
			MobileMessaging.sharedInstance?.stop()
		}
	}
	
	/**
	Logging utility is used for:
	- setting up logging options and logging levels.
	- obtaining a path to the logs file, in case the Logging utility is set up to log in file (logging options contains `.File` option).
	*/
	public static let loggingUtil = MMLoggingUtil()
	
	/**
	//TODO: docs
	*/
//	public static let geofencingService = MMGeofencingService.sharedInstance
	
	/**
	This method handles a new APNs device token and updates user's registration on the server. This method should be called form AppDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` callback.
	- parameter token: A token that identifies a particular device to APNs.
	*/
	public class func didRegisterForRemoteNotificationsWithDeviceToken(_ token: Data) {
		MobileMessaging.sharedInstance?.didRegisterForRemoteNotificationsWithDeviceToken(token)
	}
	
	/**
	This method handles incoming remote notifications and triggers sending procedure for delivery reports. The method should be called from AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback.
	- parameter userInfo: A dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	- parameter fetchCompletionHandler: A block to execute when the download operation is complete. The block is originally passed to AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback as a `fetchCompletionHandler` parameter. Mobile Messaging will execute this block after sending notification's delivery report.
	*/
	public class func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		MobileMessaging.sharedInstance?.didReceiveRemoteNotification(userInfo, newMessageReceivedCallback: nil, completion: { result in
			completionHandler(.newData)
		})

		if UIApplication.shared.applicationState == .inactive {
			notificationTapHandler?(userInfo as [NSObject : AnyObject])
		}
	}
	
	/**
	This method handles actions of interactive notification and triggers procedure for performing operations that are defined for this action. The method should be called from AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)` and `application(_:handleActionWithIdentifier:forRemoteNotification:completionHandler:)` callbacks.
	
	- parameter identifier: The identifier associated with the action of interactive notification.
	- parameter userInfo: A dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	- parameter responseInfo: The data dictionary sent by the action.
	- parameter completionHandler: The block to execute when specified action performing finished. The block is originally passed to AppDelegate's `application(_:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:)` and `application(_:handleActionWithIdentifier:forRemoteNotification:completionHandler:)` callbacks as a `completionHandler` parameter. Mobile Messaging will execute this block after performing all actions.
    */
	public class func handleActionWithIdentifier(_ identifier: String?, userInfo: [AnyHashable : Any], responseInfo: [AnyHashable : Any]?, completionHandler: @escaping (Void) -> Void) {
		MMMessage.performAction(identifier: identifier, userInfo: userInfo as [NSObject : AnyObject], responseInfo: responseInfo, completionHandler: completionHandler)
	}
	
	/**
	Maintains attributes related to the current application installation such as APNs device token, badge number, etc.
	*/
	public class var currentInstallation: MMInstallation? {
		return MobileMessaging.sharedInstance?.currentInstallation
	}
	
	/**
	Maintains attributes related to the current user such as unique ID for the registered user, email, MSISDN, custom data, external id.
	*/
	public class var currentUser: MMUser? {
		return MobileMessaging.sharedInstance?.currentUser
	}
    
    /**
	This method sets seen status for messages and sends a corresponding request to the server. If something went wrong, the library will repeat the request until it reaches the server.
	- parameter messageIds: Array of identifiers of messages that need to be marked as seen.
    */
    public class func setSeen(messageIds: [String]) {
        MobileMessaging.sharedInstance?.setSeen(messageIds)
    }
	
	//FIXME: MOMEssage should be replaced with something lighter
	/**
	This method sends mobile originated messages to the server.
	- parameter messages: Array of objects of `MOMessage` class that need to be sent.
	- parameter completion: The block to execute after the server responded, passes an array of `MOMessage` messages, that cont
	*/
	public class func sendMessages(messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		MobileMessaging.sharedInstance?.sendMessages(messages, completion: completion)
	}
	
	/**
	A boolean variable that indicates whether the library will be sending the carrier information to the server.
	Default value is `false`.
    */
	public static var carrierInfoSendingDisabled: Bool = false
	
	/**
	A boolean variable that indicates whether the library will be sending the system information such as OS version, device model, application version to the server.
	Default value is `false`.
	*/
	public static var systemInfoSendingDisabled: Bool = false
	
	/**
	A block object to be executed when user opens the app by tapping on the notification alert. This block takes a single NSDictionary that contains information related to the notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	*/
	public static var notificationTapHandler: (([NSObject : AnyObject]) -> Void)?


//MARK: Internal
	func cleanUpAndStop() {
		MMLogDebug("Cleaning up MobileMessaging service...")
		MobileMessaging.singletonQueue.executeSync {
			self.storage?.drop()
			self.stop()
		}
	}
	
	func stop() {
		MMLogInfo("Stopping MobileMessaging service...")
		if UIApplication.shared.isRegisteredForRemoteNotifications {
			UIApplication.shared.unregisterForRemoteNotifications()
		}
		MobileMessaging.singletonQueue.executeSync {
			self.storage = nil
			self.currentInstallation = nil
			self.appListener = nil
			self.messageHandler = nil
		}
	}
	
	func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], newMessageReceivedCallback: (([AnyHashable : Any]) -> Void)? = nil, completion: ((NSError?) -> Void)? = nil) {
		MMLogDebug("New remote notification received \(userInfo)")
		MobileMessaging.singletonQueue.executeAsync {
			self.messageHandler?.handleAPNSMessage(userInfo, newMessageReceivedCallback: newMessageReceivedCallback, completion: completion)
		}
	}
	
	func didRegisterForRemoteNotificationsWithDeviceToken(_ token: Data, completion: ((NSError?) -> Void)? = nil) {
		MMLogDebug("Application did register with device token \(token.mm_toHexString)")
		NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationDeviceTokenReceived, userInfo: [MMNotificationKeyDeviceToken: token.mm_toHexString])
		MobileMessaging.singletonQueue.executeAsync {
			self.currentInstallation?.updateDeviceToken(token: token, completion: completion)
		}
	}
	
	func setSeen(_ messageIds: [String], completion: ((MMSeenMessagesResult) -> Void)? = nil) {
		MMLogDebug("Setting seen status: \(messageIds)")
		MobileMessaging.singletonQueue.executeAsync {
			self.messageHandler?.setSeen(messageIds, completion: completion)
		}
	}
	
	func sendMessages(_ messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		MMLogDebug("Sending mobile originated messages...")
		MobileMessaging.singletonQueue.executeAsync {
			self.messageHandler?.sendMessages(messages, completion: completion)
		}
	}
	
	//MARK: Private
	private static let singletonQueue: MMQueueObject = MMQueue.Serial.New.MobileMessagingSingletonQueue.queue
	
	private var valuesStorage = [NSObject: AnyObject]()
	
	public override func setValue(_ value: Any?, forKey key: String) {
		MobileMessaging.singletonQueue.executeAsync {
			self.valuesStorage[key as NSObject] = value as AnyObject
		}
	}
	
	public override func value(forKey key: String) -> Any? {
		var result: AnyObject?
		MobileMessaging.singletonQueue.executeSync {
			result = self.valuesStorage[key as NSObject]
		}
		return result
	}

	private(set) var storage: MMCoreDataStorage? {
		get { return self.value(forKey: "storage") as? MMCoreDataStorage }
		set { self.setValue(newValue, forKey: "storage") }
	}
	
	private(set) var currentInstallation: MMInstallation? {
		get { return self.value(forKey: "currentInstallation") as? MMInstallation }
		set { self.setValue(newValue, forKey: "currentInstallation") }
	}
	
	private(set) var currentUser: MMUser? {
		get { return self.value(forKey: "currentUser") as? MMUser }
		set { self.setValue(newValue, forKey: "currentUser") }
	}
	
	private(set) var appListener: MMApplicationListener? {
		get { return self.value(forKey: "appListener") as? MMApplicationListener }
		set { self.setValue(newValue, forKey: "appListener") }
	}
	
	private(set) var messageHandler: MMMessageHandler? {
		get { return self.value(forKey: "messageHandler") as? MMMessageHandler }
		set { self.setValue(newValue, forKey: "messageHandler") }
	}
}
