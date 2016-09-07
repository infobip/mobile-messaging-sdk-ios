//
//  MobileMessaging.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//
//

import Foundation
import MMAFNetworking

public final class MobileMessaging: NSObject {
	
	//MARK: Public
	public class func withApplicationCode(code: String, notificationType: UIUserNotificationType) -> MobileMessaging {
		sharedInstance = MobileMessaging(applicationCode: code, notificationType: notificationType)
		return sharedInstance!
	}
	
	public func withBackendBaseURL(urlString: String) -> MobileMessaging {
		remoteAPIBaseURL = urlString
		return self
	}
	
	public func withGeofencingServiceDisabled(disabled: Bool) -> MobileMessaging {
		MMGeofencingService.geoServiceEnabled = !disabled
		return self
	}
	
	/// Starts a new Mobile Messaging session.
	///
	/// This method should be called form AppDelegate's `application(_:didFinishLaunchingWithOptions:)` callback.
	/// - remark: For now, Mobile Messaging SDK doesn't support Badge. You should handle the badge counter by yourself.
	/// - parameter userNotificationType: Preferable notification types that indicating how the app alerts the user when a  push notification arrives.
	/// - parameter applicationCode: The application code of your Application from Push Portal website.
	/// - parameter backendBaseURL: Your backend server base URL, optional parameter. Default is http://oneapi.infobip.com.
	public func start(completion: (Void -> Void)? = nil) {
		MMLogDebug("Starting MobileMessaging service...")
		
		MobileMessaging.singletonQueue.executeAsync {
			do {
				var storage: MMCoreDataStorage?
				switch self.storageType {
				case .InMemory:
					storage = try MMCoreDataStorage.makeInMemoryStorage()
				case .SQLite:
					storage = try MMCoreDataStorage.makeSQLiteStorage()
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
					
					MMGeofencingService.sharedInstance.start()
					
					MMLogInfo("MobileMessaging SDK service successfully initialized.")
				}
			} catch {
				MMLogError("Unable to initialize Core Data stack. MobileMessaging SDK service stopped because of the fatal error.")
			}

			if UIApplication.sharedApplication().isRegisteredForRemoteNotifications() && self.currentInstallation?.deviceToken == nil {
				MMLogDebug("The application is registered for remote notifications but MobileMessaging lacks of device token. Unregistering...")
				UIApplication.sharedApplication().unregisterForRemoteNotifications()
			}
			
			if UIApplication.sharedApplication().isRegisteredForRemoteNotifications() == false {
				MMLogDebug("Registering for remote notifications...")
				UIApplication.sharedApplication().registerForRemoteNotifications()
			}
		}
	}
	
	/// Stops the currently running Mobile Messaging session.
	public class func stop(cleanUpData: Bool = false) {
		if cleanUpData {
			MobileMessaging.sharedInstance?.cleanUpAndStop()
		} else {
			MobileMessaging.sharedInstance?.stop()
		}
	}
	
	/// Logging utility is used for:
	/// - setting up the logging options and logging levels.
	/// - obtaining a path to the logs file in case the Logging utility is set up to log in file (logging options contains `.file` option).
	public internal(set) static var loggingUtil = MMLoggingUtil()
	
	/// This service manages geofencing areas, emits geografical regions entering/exiting notifications.
	///
	/// You access the Geofencing service APIs through this property.
	public internal(set) static var geofencingService = MMGeofencingService.sharedInstance
	
	/// This method handles a new APNs device token and updates user's registration on the server.
	///
	/// This method should be called form AppDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` callback.
	/// - parameter token: A token that identifies a particular device to APNs.
	public class func didRegisterForRemoteNotificationsWithDeviceToken(token: NSData) {
		MobileMessaging.sharedInstance?.didRegisterForRemoteNotificationsWithDeviceToken(token)
	}
	
	/// This method handles incoming remote notifications and triggers sending procedure for delivery reports. The method should be called from AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback.
	///
	/// - parameter userInfo: A dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	/// - parameter fetchCompletionHandler: A block to execute when the download operation is complete. The block is originally passed to AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback as a `fetchCompletionHandler` parameter. Mobile Messaging will execute this block after sending notification's delivery report.
	public class func didReceiveRemoteNotification(userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
		MobileMessaging.sharedInstance?.didReceiveRemoteNotification(userInfo, newMessageReceivedCallback: nil, completion: { result in
			completionHandler?(.NewData)
		})

		if UIApplication.sharedApplication().applicationState == .Inactive {
			notificationTapHandler?(userInfo)
		}
	}
	
	/// Maintains attributes related to the current application installation such as APNs device token, badge number, etc.
	public class var currentInstallation: MMInstallation? {
		return MobileMessaging.sharedInstance?.currentInstallation
	}
	
	/// Maintains attributes related to the current user such as unique ID for the registered user, email, MSISDN, custom data, external id.
	public class var currentUser: MMUser? {
		return MobileMessaging.sharedInstance?.currentUser
	}
	
	/// This method sets seen status for messages and sends a corresponding request to the server. If something went wrong, the library will repeat the request until it reaches the server.
	/// - parameter messageIds: Array of identifiers of messages that need to be marked as seen.
    public class func setSeen(messageIds: [String]) {
        MobileMessaging.sharedInstance?.setSeen(messageIds)
    }
	
	//FIXME: MOMEssage should be replaced with something lighter
	/// This method sends mobile originated messages to the server.
	/// - parameter messages: Array of objects of `MOMessage` class that need to be sent.
	/// - parameter completion: The block to execute after the server responded, passes an array of `MOMessage` messages, that cont
	public class func sendMessages(messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		MobileMessaging.sharedInstance?.sendMessages(messages, completion: completion)
	}
	
	/// A boolean variable that indicates whether the library will be sending the carrier information to the server.
	///
	/// Default value is `false`.
	public static var carrierInfoSendingDisabled: Bool = false
	
	/// A boolean variable that indicates whether the library will be sending the system information such as OS version, device model, application version to the server.
	///
	/// Default value is `false`.
	public static var systemInfoSendingDisabled: Bool = false
	
	/// A block object to be executed when user opens the app by tapping on the notification alert. This block takes a single NSDictionary that contains information related to the notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	public static var notificationTapHandler: (([NSObject : AnyObject]) -> Void)?

	public static var userAgent = MMUserAgent()
	
//MARK: Internal
	static var sharedInstance: MobileMessaging?
	let userNotificationType: UIUserNotificationType
	let applicationCode: String
	
	var	storageType: MMStorageType = .SQLite
	var remoteAPIBaseURL: String = MMAPIValues.kProdBaseURLString
	var geofencingServiceDisabled: Bool = false
	
	func cleanUpAndStop() {
		MMLogDebug("Cleaning up MobileMessaging service...")
		MobileMessaging.singletonQueue.executeSync {
			self.storage?.drop()
			self.stop()
		}
	}
	
	func stop() {
		MMLogInfo("Stopping MobileMessaging service...")
		if UIApplication.sharedApplication().isRegisteredForRemoteNotifications() {
			UIApplication.sharedApplication().unregisterForRemoteNotifications()
		}
		MobileMessaging.singletonQueue.executeSync {
			self.storage = nil
			self.currentInstallation = nil
			self.appListener = nil
			self.messageHandler = nil
		}
	}
	
	func didReceiveRemoteNotification(userInfo: [NSObject : AnyObject], newMessageReceivedCallback: ([NSObject : AnyObject] -> Void)? = nil, completion: ((NSError?) -> Void)? = nil) {
		MMLogDebug("New remote notification received \(userInfo)")
		MobileMessaging.singletonQueue.executeAsync {
			self.messageHandler?.handleAPNSMessage(userInfo, newMessageReceivedCallback: newMessageReceivedCallback, completion: completion)
		}
	}
	
	func didRegisterForRemoteNotificationsWithDeviceToken(token: NSData, completion: (NSError? -> Void)? = nil) {
		MMLogDebug("Application did register with device token \(token.mm_toHexString)")
		NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationDeviceTokenReceived, userInfo: [MMNotificationKeyDeviceToken: token.mm_toHexString])
		MobileMessaging.singletonQueue.executeAsync {
			self.currentInstallation?.updateDeviceToken(token, completion: completion)
		}
	}
	
	func setSeen(messageIds: [String], completion: (MMSeenMessagesResult -> Void)? = nil) {
		MMLogDebug("Setting seen status: \(messageIds)")
		MobileMessaging.singletonQueue.executeAsync {
			self.messageHandler?.setSeen(messageIds, completion: completion)
		}
	}
	
	func sendMessages(messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		MMLogDebug("Sending mobile originated messages...")
		MobileMessaging.singletonQueue.executeAsync {
			self.messageHandler?.sendMessages(messages, completion: completion)
		}
	}
	
	//MARK: Private
	private init(applicationCode: String, notificationType: UIUserNotificationType) {
		self.applicationCode = applicationCode
		self.userNotificationType = notificationType
	}
	
	private static let singletonQueue: MMQueueObject = MMQueue.Serial.New.MobileMessagingSingletonQueue.queue
	
	private var valuesStorage = [NSObject: AnyObject]()

	public override func setValue(value: AnyObject?, forKey key: String) {
		MobileMessaging.singletonQueue.executeAsync {
			self.valuesStorage[key] = value
		}
	}
	
	public override func valueForKey(key: String) -> AnyObject? {
		var result: AnyObject?
		MobileMessaging.singletonQueue.executeSync {
			result = self.valuesStorage[key]
		}
		return result
	}
	
	private(set) var storage: MMCoreDataStorage? {
		get { return self.valueForKey("storage") as? MMCoreDataStorage }
		set { self.setValue(newValue, forKey: "storage") }
	}
	
	private(set) var currentInstallation: MMInstallation? {
		get { return self.valueForKey("currentInstallation") as? MMInstallation }
		set { self.setValue(newValue, forKey: "currentInstallation") }
	}
	
	private(set) var currentUser: MMUser? {
		get { return self.valueForKey("currentUser") as? MMUser }
		set { self.setValue(newValue, forKey: "currentUser") }
	}
	
	private(set) var appListener: MMApplicationListener? {
		get { return self.valueForKey("appListener") as? MMApplicationListener }
		set { self.setValue(newValue, forKey: "appListener") }
	}
	
	private(set) var messageHandler: MMMessageHandler? {
		get { return self.valueForKey("messageHandler") as? MMMessageHandler }
		set { self.setValue(newValue, forKey: "messageHandler") }
	}
}