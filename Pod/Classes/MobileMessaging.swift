//
//  MobileMessaging.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//
//

import Foundation

public final class MobileMessaging: NSObject {
	//MARK: Public

	/// Fabric method for Mobile Messaging session.
	/// - parameter userNotificationType: Preferable notification types that indicating how the app alerts the user when a  push notification arrives.
	/// - parameter applicationCode: The application code of your Application from Push Portal website.
	public class func withApplicationCode(_ code: String, notificationType: UIUserNotificationType) -> MobileMessaging {
		sharedInstance = MobileMessaging(applicationCode: code, notificationType: notificationType)
		return sharedInstance!
	}
	
	/// Fabric method for Mobile Messaging session.
	/// - parameter backendBaseURL: Your backend server base URL, optional parameter. Default is http://oneapi.infobip.com.
	public func withBackendBaseURL(_ urlString: String) -> MobileMessaging {
		self.remoteAPIBaseURL = urlString
		return self
	}
	
	/// Fabric method for Mobile Messaging session.
	/// Use this method to enable the Geofencing service.
	public func withGeofencingService() -> MobileMessaging {
		self.isGeoServiceEnabled = true
		return self
	}
	
	/// Fabric method for Mobile Messaging session.
	/// It is possible to supply a default implementation of Message Storage to the Mobile Messaging library during initialization. In this case the library will save all received Push messages using the `MMDefaultMessageStorage`. Library can also be initialized either without message storage or with user-provided one (see `withMessageStorage(messageStorage:)`).
	public func withDefaultMessageStorage() -> MobileMessaging {
		self.messageStorage = MMDefaultMessageStorage()
		return self
	}
	
	/// Fabric method for Mobile Messaging session.
	/// It is possible to supply an implementation of Message Storage to the Mobile Messaging library during initialization. In this case the library will save all received Push messages to the supplied `messageStorage`. Library can also be initialized either without message storage or with the default message storage (see `withDefaultMessageStorage()` method).
	/// - parameter messageStorage: a storage object, that implements the `MessageStorage` protocol
	public func withMessageStorage(_ messageStorage: MessageStorage) -> MobileMessaging {
		self.messageStorage = messageStorage
		return self
	}
	
	/// Starts a new Mobile Messaging session.
	///
	/// This method should be called form AppDelegate's `application(_:didFinishLaunchingWithOptions:)` callback.
	/// - remark: For now, Mobile Messaging SDK doesn't support Badge. You should handle the badge counter by yourself.
	public func start(_ completion: ((Void) -> Void)? = nil) {
		MMLogDebug("Starting MobileMessaging service...")
		do {
			var storage: MMCoreDataStorage?
			switch self.storageType {
			case .InMemory:
				storage = try MMCoreDataStorage.makeInMemoryStorage()
			case .SQLite:
				storage = try MMCoreDataStorage.makeSQLiteInternalStorage()
			}
			if let storage = storage {
				self.internalStorage = storage
				let installation = MMInstallation(storage: storage, baseURL: self.remoteAPIBaseURL, applicationCode: self.applicationCode)
				self.currentInstallation = installation
				let user = MMUser(installation: installation)
				self.currentUser = user
				let messageHandler = MMMessageHandler(storage: storage, baseURL: self.remoteAPIBaseURL, applicationCode: self.applicationCode)
				self.messageHandler = messageHandler
				self.startMessageStorage()
				
				if isGeoServiceEnabled {
					self.geofencingService = MMGeofencingService(storage: storage, remoteAPIQueue: MMRemoteAPIQueue(baseURL: self.remoteAPIBaseURL, applicationCode: self.applicationCode))
					self.geofencingService?.start()
				}
				self.appListener = MMApplicationListener(messageHandler: messageHandler, installation: installation, user: user, geofencingService: self.geofencingService)
				MMLogInfo("MobileMessaging SDK service successfully initialized.")
			}
		} catch {
			MMLogError("Unable to initialize Core Data stack. MobileMessaging SDK service stopped because of the fatal error.")
		}
		
		if UIApplication.shared.isRegisteredForRemoteNotifications && self.currentInstallation?.deviceToken == nil {
			MMLogDebug("The application is registered for remote notifications but MobileMessaging lacks of device token. Unregistering...")
			UIApplication.shared.unregisterForRemoteNotifications()
		}
		
		UIApplication.shared.registerUserNotificationSettings(UIUserNotificationSettings(types: self.userNotificationType, categories: nil))
		
		if UIApplication.shared.isRegisteredForRemoteNotifications == false {
			MMLogDebug("Registering for remote notifications...")
			UIApplication.shared.registerForRemoteNotifications()
		}
        
        #if DEBUG
        MMVersionManager.shared?.validateVersion()
        #endif
        
		completion?()
	}
	
	/// Stops the currently running Mobile Messaging session.
	public class func stop(_ cleanUpData: Bool = false) {
		if cleanUpData {
			MobileMessaging.sharedInstance?.cleanUpAndStop()
		} else {
			MobileMessaging.sharedInstance?.stop()
		}
	}
	
	/// Logging utility is used for:
	/// - setting up the logging options and logging levels.
	/// - obtaining a path to the logs file in case the Logging utility is set up to log in file (logging options contains `.file` option).
	public static var logger: MMLogging = MMLogger()

	/// This service manages geofencing areas, emits geografical regions entering/exiting notifications.
	///
	/// You access the Geofencing service APIs through this property.
	public class var geofencingService: MMGeofencingService? {
		return MobileMessaging.sharedInstance?.geofencingService
	}
	
	/// This method handles a new APNs device token and updates user's registration on the server.
	///
	/// This method should be called form AppDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` callback.
	/// - parameter token: A token that identifies a particular device to APNs.
	public class func didRegisterForRemoteNotificationsWithDeviceToken(_ token: Data) {
		MobileMessaging.sharedInstance?.didRegisterForRemoteNotificationsWithDeviceToken(token)
	}
	
	/// This method handles incoming remote notifications and triggers sending procedure for delivery reports. The method should be called from AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback.
	///
	/// - parameter userInfo: A dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	/// - parameter fetchCompletionHandler: A block to execute when the download operation is complete. The block is originally passed to AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback as a `fetchCompletionHandler` parameter. Mobile Messaging will execute this block after sending notification's delivery report.
	public class func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		MobileMessaging.sharedInstance?.didReceiveRemoteNotification(userInfo, newMessageReceivedCallback: nil, completion: { result in
			completionHandler(.newData)
		})
		if UIApplication.shared.applicationState == .inactive {
			notificationTapHandler?(userInfo)
		}
	}
	
	/// Maintains attributes related to the current application installation such as APNs device token, badge number, etc.
	public class var currentInstallation: MMInstallation? {
		return MobileMessaging.sharedInstance?.currentInstallation
	}
	
	/// Returns the default message storage if used. For more information see `MMDefaultMessageStorage` class description.
	public class var defaultMessageStorage: MMDefaultMessageStorage? {
		return MobileMessaging.sharedInstance?.messageStorage as? MMDefaultMessageStorage
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
	public class func sendMessages(_ messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
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
	
	/// An auxillary component provides the convinient access to the user agent data.
	public static var userAgent = MMUserAgent()
	
	/// A block object to be executed when user opens the app by tapping on the notification alert. This block takes a single NSDictionary that contains information related to the notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	public static var notificationTapHandler: (([AnyHashable: Any]) -> Void)?
	
	/// The message handling object defines the behaviour that is triggered during the message handling.
	///
	/// You can implement your own message handling either by subclassing `MMDefaultMessageHandling` or implementing the `MessageHandling` protocol.
	public static var messageHandling: MessageHandling = MMDefaultMessageHandling()
	
//MARK: Internal
	static var sharedInstance: MobileMessaging?
	let userNotificationType: UIUserNotificationType
	let applicationCode: String
	
	var	storageType: MMStorageType = .SQLite
	var remoteAPIBaseURL: String = MMAPIValues.kProdBaseURLString
	var isGeoServiceEnabled: Bool = false
	
	func cleanUpAndStop() {
		MMLogDebug("Cleaning up MobileMessaging service...")
		self.internalStorage?.drop()
		(MobileMessaging.sharedInstance?.messageStorage as? MMDefaultMessageStorage)?.coreDataStorage?.drop()
		self.stop()
	}
	
	func stop() {
		MMLogInfo("Stopping MobileMessaging service...")
		if UIApplication.shared.isRegisteredForRemoteNotifications {
			UIApplication.shared.unregisterForRemoteNotifications()
		}

		self.internalStorage = nil
		self.currentInstallation = nil
		self.appListener = nil
		self.messageHandler = nil
		self.currentUser = nil
		self.messageStorage?.stop()
		self.messageStorage = nil
		
		MobileMessaging.messageHandling = MMDefaultMessageHandling()
		MobileMessaging.geofencingService?.stop()
		self.geofencingService = nil
	}
	
	func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], newMessageReceivedCallback: (([AnyHashable : Any]) -> Void)? = nil, completion: ((NSError?) -> Void)? = nil) {
		MMLogDebug("New remote notification received \(userInfo)")
		self.messageHandler?.handleAPNSMessage(userInfo, newMessageReceivedCallback: newMessageReceivedCallback, completion: completion)
	}
	
	func didRegisterForRemoteNotificationsWithDeviceToken(_ token: Data, completion: ((NSError?) -> Void)? = nil) {
		MMLogDebug("Application did register with device token \(token.mm_toHexString)")
		NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationDeviceTokenReceived, userInfo: [MMNotificationKeyDeviceToken: token.mm_toHexString])
		self.currentInstallation?.updateDeviceToken(token: token, completion: completion)
	}
	
	func setSeen(_ messageIds: [String], completion: ((MMSeenMessagesResult) -> Void)? = nil) {
		MMLogDebug("Setting seen status: \(messageIds)")
		self.messageHandler?.setSeen(messageIds, completion: completion)
	}
	
	func sendMessages(_ messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		MMLogDebug("Sending mobile originated messages...")
		self.messageHandler?.sendMessages(messages, completion: completion)
	}
	
	//MARK: Private
	private func startMessageStorage() {
		self.messageStorage?.start()
	}
	
	private init(applicationCode: String, notificationType: UIUserNotificationType) {
		self.applicationCode = applicationCode
		self.userNotificationType = notificationType
	}


	
	class var messageStorage: MessageStorage? {
		return MobileMessaging.sharedInstance?.messageStorage
	}
	
	var messageStorageAdapter: MMMessageStorageQueuedAdapter?
	private(set) var messageStorage: MessageStorage? {
		didSet {
			messageStorageAdapter = MMMessageStorageQueuedAdapter(adapteeStorage: messageStorage)
		}
	}
	private(set) var internalStorage: MMCoreDataStorage?
	private(set) var currentInstallation: MMInstallation?
	private(set) var currentUser: MMUser?
	private(set) var appListener: MMApplicationListener?
	private(set) var messageHandler: MMMessageHandler?
	internal(set) var geofencingService: MMGeofencingService?
}
