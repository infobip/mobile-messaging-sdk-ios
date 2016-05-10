//
//  MobileMessaging.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//
//

import Foundation
import MMMagicalRecord
import MMAFNetworking

public final class MobileMessaging: NSObject {
	//MARK: Public
	/**
	Starts new Mobile Messaging session. This method should be called form within AppDelegate's `application(_:didFinishLaunchingWithOptions:)` callback.
	- parameter code: An Application Code of your Application from Push Portal website
	- parameter backendBaseURL: Your backend server base URL, non-mandatory parameter. Default is http://oneapi.infobip.com.
	*/
	public class func startWithApplicationCode(code: String, backendBaseURL: String) {
		MobileMessagingInstance.loadComponents(code, storageType: .SQLite, remoteAPIBaseURL: backendBaseURL)
	}
	
	public class func startWithApplicationCode(code: String) {
		startWithApplicationCode(code, backendBaseURL: MMAPIValues.kProdBaseURLString)
	}
	
	/**
	Stops current Mobile Messaging session.
	*/
	public class func stop() {
		MobileMessagingInstance.sharedInstance.reset()
	}
	
	/**
	This method handles new APNs device token and updates user registration on server. This method should be called form within AppDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` callback.
	- parameter token: A token that identifies the device to APNs.
	*/
	public class func didRegisterForRemoteNotificationsWithDeviceToken(token: NSData) {
		MobileMessagingInstance.sharedInstance.didRegisterForRemoteNotificationsWithDeviceToken(token)
	}
	
	/**
	This method handles incoming remote notifications and triggers sending procedure for delivery reports. This method should be called from within AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback.
	- parameter userInfo: A dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	- parameter fetchCompletionHandler: The block to execute when the download operation is complete. The block is originally passed to AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback as a `fetchCompletionHandler` parameter. Mobile Messaging will execute this block after sending notification's delivery report.
	*/
	public class func didReceiveRemoteNotification(userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: ((UIBackgroundFetchResult) -> Void)?) {
		MMLogInfo("New remote notification received \(userInfo)")
		MobileMessagingInstance.sharedInstance.didReceiveRemoteNotification(userInfo, newMessageReceivedCallback: nil, completion: { result in
			completionHandler?(.NewData)
		})
	}
	
	/**
	LoggingUtil used for:
	- setup logging options and logging levels
	- obtaining path to log file, if logging options contains `.File` option
	*/
	public class var loggingUtil: MMLoggingUtil? {
		return MobileMessagingInstance.sharedInstance.loggingUtil
	}
	
	/**
	Maintains attributes related to current application installation such as APNs device token, unique ID for the registered user, email, MSISDN etc.
	*/
	public class var currentInstallation: MMInstallation? {
		return MobileMessagingInstance.sharedInstance.currentInstallation
	}
    
    /**
     This method set seen status for messages and sends such request to the server, if something will went wrong, service repeats requests until it reaches the server
     - parameter messageIds: Array of message ids of messages that need to be marked as seen
    */
    public class func setSeen(messageIds: [String]) {
        MobileMessagingInstance.sharedInstance.setSeen(messageIds)
    }
	
	/**
	A boolean variable that indicates whether the library will send the carrier information to the server.
	Default value is `true`
    */
	public static var shouldSendCarrierInfo : Bool = true
	
	/**
	A boolean variable that indicates whether the library will send the system information like OS version, device model, application version to the server.
	Default value is `true`
	*/
	public static var shouldSendSystemInfo : Bool = true
}

class MobileMessagingInstance {
	//MARK: Internal
	static var sharedInstance = MobileMessagingInstance()

	func reset() {
		MobileMessagingInstance.queue.executeSync {
			self.storage?.drop()
			self.storage = nil
			self.currentInstallation = nil
			self.appListener = nil
			self.messageHandler = nil
		}
	}
	
	func didReceiveRemoteNotification(userInfo: [NSObject : AnyObject], newMessageReceivedCallback: (() -> Void)? = nil, completion: ((NSError?) -> Void)? = nil) {
		MobileMessagingInstance.queue.executeAsync {
			self.messageHandler?.handleMessage(userInfo, newMessageReceivedCallback: newMessageReceivedCallback, completion: completion)
		}
	}
	
	func didRegisterForRemoteNotificationsWithDeviceToken(token: NSData, completion: (NSError? -> Void)? = nil) {
		MMLogInfo("Application did register with device token \(token.toHexString)")
		MobileMessagingInstance.queue.executeAsync {
			self.currentInstallation?.updateDeviceToken(token, completion: completion)
		}
	}
	
	func setSeen(messageIds: [String], completion: (MMSeenMessagesResult -> Void)? = nil) {
		MobileMessagingInstance.queue.executeAsync {
			self.messageHandler?.setSeen(messageIds, completion: completion)
		}
	}
	
	static func loadComponents(applicationCode: String, storageType: MMStorageType, remoteAPIBaseURL: String, completion: (() -> Void)? = nil) {
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