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
	/**
	Starts a new Mobile Messaging session. This method should be called form AppDelegate's `application(_:didFinishLaunchingWithOptions:)` callback.
	- remark: For now, Mobile Messaging SDK doesn't support badge. You should handle the badge counter by yourself.
	- parameter userNotificationType: Preferable notification types that indicating how the app alerts the user when a  push notification arrives.
	- parameter applicationCode: The application code of your Application from Push Portal website.
	- parameter backendBaseURL: Your backend server base URL, optional parameter. Default is http://oneapi.infobip.com.
	*/
	public class func startWithNotificationType(userNotificationType: UIUserNotificationType, applicationCode: String, backendBaseURL: String) {
		MobileMessagingInstance.start(userNotificationType, applicationCode: applicationCode, storageType: .SQLite, remoteAPIBaseURL: backendBaseURL)
	}
	
	public class func startWithNotificationType(userNotificationType: UIUserNotificationType, applicationCode: String) {
		startWithNotificationType(userNotificationType, applicationCode: applicationCode, backendBaseURL: MMAPIValues.kProdBaseURLString)
	}
	
	/**
	Stops current Mobile Messaging session.
	*/
	public class func stop(cleanUpData: Bool = false) {
		if cleanUpData {
			MobileMessagingInstance.sharedInstance.cleanUpAndStop()
		} else {
			MobileMessagingInstance.sharedInstance.stop()
		}
	}
	
	/**
	This method handles a new APNs device token and updates user's registration on the server. This method should be called form AppDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` callback.
	- parameter token: A token that identifies a particular device to APNs.
	*/
	public class func didRegisterForRemoteNotificationsWithDeviceToken(token: NSData) {
		MobileMessagingInstance.sharedInstance.didRegisterForRemoteNotificationsWithDeviceToken(token)
	}
	
	/**
	This method handles incoming remote notifications and triggers sending procedure for delivery reports. The method should be called from AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback.
	- parameter userInfo: A dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	- parameter fetchCompletionHandler: A block to execute when the download operation is complete. The block is originally passed to AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback as a `fetchCompletionHandler` parameter. Mobile Messaging will execute this block after sending notification's delivery report.
	*/
	public class func didReceiveRemoteNotification(userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
		MobileMessagingInstance.sharedInstance.didReceiveRemoteNotification(userInfo, newMessageReceivedCallback: nil, completion: { result in
			completionHandler?(.NewData)
		})
	}
	
	/**
	Logging utility is used for:
	- setting up logging options and logging levels.
	- obtaining a path to the logs file, in case the Logging utility is set up to log in file (logging options contains `.File` option).
	*/
	public class var loggingUtil: MMLoggingUtil? {
		return MobileMessagingInstance.sharedInstance.loggingUtil
	}
	
	/**
	Maintains attributes related to the current application installation such as APNs device token, unique ID for the registered user, email, MSISDN etc.
	*/
	public class var currentInstallation: MMInstallation? {
		return MobileMessagingInstance.sharedInstance.currentInstallation
	}
    
    /**
	This method sets seen status for messages and sends a corresponding request to the server. If something went wrong, the library will repeat the request until it reaches the server.
	- parameter messageIds: Array of identifiers of messages that need to be marked as seen.
    */
    public class func setSeen(messageIds: [String]) {
        MobileMessagingInstance.sharedInstance.setSeen(messageIds)
    }
	
	/**
	A boolean variable that indicates whether the library will be sending the carrier information to the server.
	Default value is `true`.
    */
	public static var shouldSendCarrierInfo : Bool = true
	
	/**
	A boolean variable that indicates whether the library will be sending the system information such as OS version, device model, application version to the server.
	Default value is `true`.
	*/
	public static var shouldSendSystemInfo : Bool = true
}

class MobileMessagingInstance {
	//MARK: Internal
	static var sharedInstance = MobileMessagingInstance()
	
	func cleanUpAndStop() {
		MMLogInfo("Cleaning up MobileMessaging service...")
		MobileMessagingInstance.queue.executeSync {
			self.storage?.drop()
			self.stop()
		}
	}
	
	func stop() {
		MMLogInfo("Stopping MobileMessaging service...")
		if UIApplication.sharedApplication().isRegisteredForRemoteNotifications() {
			UIApplication.sharedApplication().unregisterForRemoteNotifications()
		}
		MobileMessagingInstance.queue.executeSync {
			self.storage = nil
			self.currentInstallation = nil
			self.appListener = nil
			self.messageHandler = nil
		}
	}
	
	func didReceiveRemoteNotification(userInfo: [NSObject : AnyObject], newMessageReceivedCallback: ([NSObject : AnyObject] -> Void)? = nil, completion: ((NSError?) -> Void)? = nil) {
		MMLogInfo("New remote notification received \(userInfo)")
		MobileMessagingInstance.queue.executeAsync {
			self.messageHandler?.handleAPNSMessage(userInfo, newMessageReceivedCallback: newMessageReceivedCallback, completion: completion)
		}
	}
	
	func didRegisterForRemoteNotificationsWithDeviceToken(token: NSData, completion: (NSError? -> Void)? = nil) {
		MMLogInfo("Application did register with device token \(token.toHexString)")
		NSNotificationCenter.postNotificationFromMainThread(MMNotificationDeviceTokenReceived, userInfo: [MMNotificationKeyDeviceToken: token.toHexString])
		MobileMessagingInstance.queue.executeAsync {
			self.currentInstallation?.updateDeviceToken(token, completion: completion)
		}
	}
	
	func setSeen(messageIds: [String], completion: (MMSeenMessagesResult -> Void)? = nil) {
		MMLogInfo("Setting seen status: \(messageIds)")
		MobileMessagingInstance.queue.executeAsync {
			self.messageHandler?.setSeen(messageIds, completion: completion)
		}
	}
	
	static func start(userNotificationType: UIUserNotificationType, applicationCode: String, storageType: MMStorageType, remoteAPIBaseURL: String, completion: (() -> Void)? = nil) {
		MMLogInfo("Starting MobileMessaging service...")
		MobileMessagingInstance.queue.executeAsync {
			do {
				var storage: MMCoreDataStorage?
				switch storageType {
				case .InMemory:
					storage = try MMCoreDataStorage.newInMemoryStorage()
				case .SQLite:
					storage = try MMCoreDataStorage.SQLiteStorage()
				}
				if let storage = storage {
					MobileMessagingInstance.sharedInstance.storage = storage
					let installation = MMInstallation(storage: storage, baseURL: remoteAPIBaseURL, applicationCode: applicationCode)
					MobileMessagingInstance.sharedInstance.currentInstallation = installation
					let messageHandler = MMMessageHandler(storage: storage, baseURL: remoteAPIBaseURL, applicationCode: applicationCode)
					MobileMessagingInstance.sharedInstance.messageHandler = messageHandler
					MobileMessagingInstance.sharedInstance.appListener = MMApplicationListener(messageHandler: messageHandler, installation: installation)
					MMLogInfo("MobileMessaging SDK service successfully initialized.")
				}
			} catch {
				MMLogError("Unable to initialize Core Data stack. MobileMessaging SDK service stopped because of the fatal error.")
			}

			MobileMessagingInstance.queue.executeAsync {
				UIApplication.sharedApplication().registerUserNotificationSettings(UIUserNotificationSettings(forTypes: userNotificationType, categories: nil))
				UIApplication.sharedApplication().registerForRemoteNotifications()
			}
		}
	}
	
	//MARK: Private
	private static var queue: MMQueueObject = MMQueue.Serial.New.MobileMessagingSingletonQueue.queue
	private var valuesStorage = [NSObject: AnyObject]()
	private init() {
		self.loggingUtil = MMLoggingUtil()
	}
	
	private func setValue(value: AnyObject?, forKey key: String) {
		MobileMessagingInstance.queue.executeAsync {
			self.valuesStorage[key] = value
		}
	}
	
	private func valueForKey(key: String) -> AnyObject? {
		var result: AnyObject?
		MobileMessagingInstance.queue.executeSync {
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
	
	private(set) var appListener: MMApplicationListener? {
		get { return self.valueForKey("appListener") as? MMApplicationListener }
		set { self.setValue(newValue, forKey: "appListener") }
	}
	
	private(set) var messageHandler: MMMessageHandler? {
		get { return self.valueForKey("messageHandler") as? MMMessageHandler }
		set { self.setValue(newValue, forKey: "messageHandler") }
	}
	
	private(set) var loggingUtil : MMLoggingUtil
}