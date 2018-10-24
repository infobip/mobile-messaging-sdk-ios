//
//  MobileMessaging.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//
//

import Foundation
import UserNotifications

@objcMembers
public final class MobileMessaging: NSObject {
	//MARK: Public
	
	/// Fabric method for Mobile Messaging session.
	/// - parameter code: The application code of your Application from Push Portal website.
	/// - parameter notificationType: Preferable notification types that indicating how the app alerts the user when a push notification arrives.
	public class func withApplicationCode(_ code: String, notificationType: UserNotificationType) -> MobileMessaging? {
		return MobileMessaging.withApplicationCode(code, notificationType: notificationType, backendBaseURL: Consts.APIValues.prodDynamicBaseURLString)
	}
	
	/// Fabric method for Mobile Messaging session.
	/// - parameter code: The application code of your Application from Push Portal website.
	/// - parameter notificationType: Preferable notification types that indicating how the app alerts the user when a push notification arrives.
	/// - parameter forceCleanup: Defines whether the SDK must be cleaned up on startup.
	/// - warning: The cleanup (parameter `forceCleanup = true`) must be performed manually if you changed the application code while `PrivacySettings.applicationCodePersistingDisabled` is set to `true`.
	public class func withApplicationCode(_ code: String, notificationType: UserNotificationType, forceCleanup: Bool) -> MobileMessaging? {
		return MobileMessaging.withApplicationCode(code, notificationType: notificationType, backendBaseURL: Consts.APIValues.prodDynamicBaseURLString, forceCleanup: forceCleanup)
	}
	
	/// Fabric method for Mobile Messaging session.
	/// - parameter notificationType: Preferable notification types that indicating how the app alerts the user when a push notification arrives.
	/// - parameter code: The application code of your Application from Push Portal website.
	/// - parameter backendBaseURL: Your backend server base URL, optional parameter. Default is https://oneapi.infobip.com.
	public class func withApplicationCode(_ code: String, notificationType: UserNotificationType, backendBaseURL: String) -> MobileMessaging? {
		return MobileMessaging.withApplicationCode(code, notificationType: notificationType, backendBaseURL: backendBaseURL, forceCleanup: false)
	}
	
	/// Fabric method for Mobile Messaging session.
	/// It is possible to supply a default implementation of Message Storage to the Mobile Messaging library during initialization. In this case the library will save all received Push messages using the `MMDefaultMessageStorage`. Library can also be initialized either without message storage or with user-provided one (see `withMessageStorage(messageStorage:)`).
	public func withDefaultMessageStorage() -> MobileMessaging {
		self.messageStorages[MessageStorageKind.messages.rawValue] = MessageStorageQueuedAdapter.makeDefaultMessagesStoragaAdapter()
		return self
	}
	
	/// Fabric method for Mobile Messaging session.
	/// It is possible to supply an implementation of Message Storage to the Mobile Messaging library during initialization. In this case the library will save all received Push messages to the supplied `messageStorage`. Library can also be initialized either without message storage or with the default message storage (see `withDefaultMessageStorage()` method).
	/// - parameter messageStorage: a storage object, that implements the `MessageStorage` protocol
	public func withMessageStorage(_ messageStorage: MessageStorage) -> MobileMessaging {
		self.messageStorages[MessageStorageKind.messages.rawValue] = MessageStorageQueuedAdapter.makeMessagesStoragaAdapter(storage: messageStorage)
		return self
	}
	
	/// Fabric method for Mobile Messaging session.
	/// It is possible to postpone the registration for Push Notifications. It is up to you to define when and where the user will be promt to allow receiving Push Notifications. By default the registration is being performed by `MobileMessaging.start()` call.
	/// - remark: Don't forget to register for Push Notifications explicitly by calling `MobileMessaging.registerForRemoteNotifications()`.
	public func withoutRegisteringForRemoteNotifications() -> MobileMessaging {
		doRegisterToApns = false
		return self
	}
	
	/// Starts a new Mobile Messaging session.
	///
	/// This method should be called form AppDelegate's `application(_:didFinishLaunchingWithOptions:)` callback.
	/// - remark: For now, Mobile Messaging SDK doesn't support Badge. You should handle the badge counter by yourself.
	public func start(_ completion: (() -> Void)? = nil) {
		self.doStart(completion)
	}
	
	/// Syncronizes all available subservices with the server.
	public static func sync() {
		MobileMessaging.sharedInstance?.sync()
	}

	/// Sets primary device setting
	/// Single user profile on Infobip Portal can have one or more mobile devices with the application installed. You might want to mark one of such devices as a primary device and send push messages only to this device (i.e. receive bank authorization codes only on one device).
	/// - parameter isPrimary: defines whether to set current device as primery one or not
	/// - parameter completion: called after the setting is finished sync with the server
	public static func setAsPrimaryDevice(_ isPrimary: Bool, completion: ((NSError?) -> Void)? = nil) {
		guard let mm = MobileMessaging.sharedInstance else {
			completion?(NSError(type: MMInternalErrorType.UnknownError))
			return
		}
		mm.setAsPrimaryDevice(isPrimary, completion: completion)
	}
    
    /// Synchronizes primary device setting with server
    public static func syncPrimaryDevice(completion: @escaping ((_ isPrimary: Bool, _ error: NSError?) -> Void)) {
        guard let mm = MobileMessaging.sharedInstance else {
            completion(isPrimaryDevice, NSError(type: MMInternalErrorType.UnknownError))
            return
        }
        mm.syncPrimarySettingWithServer(completion: completion)
    }

	/// Primary device setting
	/// Single user profile on Infobip Portal can have one or more mobile devices with the application installed. You might want to mark one of such devices as a primary device and send push messages only to this device (i.e. receive bank authorization codes only on one device).
	public static var isPrimaryDevice: Bool {
		get {
			return MobileMessaging.sharedInstance?.isPrimaryDevice ?? false
		}
		set {
			MobileMessaging.sharedInstance?.isPrimaryDevice = newValue
		}
	}
	
	/// Current push registration status.
	/// The status defines whether the device is allowed to be receiving push notifications (regular push messages/geofencing campaign messages/messages fetched from the server).
	/// MobileMessaging SDK has the push registration enabled by default.
	public static var isPushRegistrationEnabled: Bool {
		return MobileMessaging.sharedInstance?.isPushRegistrationEnabled ?? true
	}
	
	/// Cleans up all internal persisted data.
	///
	/// Use this method in order to completely drop any data persisted by the SDK (i.e. internal SDK data, optional user data, optional messages metadata).
	/// - Parameter clearKeychain: defines whether the internalId in keychain will be cleaned. True by default.
	public static func cleanUpAndStop(_ clearKeychain: Bool = true) {
		MobileMessaging.sharedInstance?.cleanUpAndStop(clearKeychain)
	}
	
	/// Enables the push registration so the device can receive push notifications (regular push messages/geofencing campaign messages/messages fetched from the server).
	/// MobileMessaging SDK has the push registration enabled by default.
	public static func enablePushRegistration(completion: ((NSError?) -> Void)? = nil) {
		guard let mm = MobileMessaging.sharedInstance else {
			completion?(NSError(type: MMInternalErrorType.UnknownError))
			return
		}
		mm.updateRegistrationEnabledStatus(true, completion: completion)
	}
	
	/// Disables the push registration so the device no longer receives any push notifications (regular push messages/geofencing campaign messages/messages fetched from the server).
	/// MobileMessaging SDK has the push registration enabled by default.
	public static func disablePushRegistration(completion: ((NSError?) -> Void)? = nil) {
		guard let mm = MobileMessaging.sharedInstance else {
			completion?(NSError(type: MMInternalErrorType.UnknownError))
			return
		}
		mm.updateRegistrationEnabledStatus(false, completion: completion)
	}
	
	/// Stops all the currently running Mobile Messaging services.
	/// - Parameter cleanUpData: defines whether the Mobile Messaging internal storage will be dropped. False by default.
	/// - Attention: This function doesn't disable push notifications, they are still being received by the OS.
	public class func stop(_ cleanUpData: Bool = false) {
		if cleanUpData {
			MobileMessaging.sharedInstance?.cleanUpAndStop()
		} else {
			MobileMessaging.sharedInstance?.stop()
		}
	}
	
	/// Call this method to initiate the registration process with Apple Push Notification service. User will be promt to allow receiving Push Notifications.
	public class func registerForRemoteNotifications() {
		MobileMessaging.sharedInstance?.apnsRegistrationManager.registerForRemoteNotifications()
	}
	
	/// Logging utility is used for:
	/// - setting up the logging options and logging levels.
	/// - obtaining a path to the logs file in case the Logging utility is set up to log in file (logging options contains `.file` option).
	public static var logger: MMLogging? = (MMLoggerFactory() as MMLoggerFactoryProtocol).createLogger?()
	
	/// This method handles a new APNs device token and updates user's registration on the server.
	///
	/// This method should be called form AppDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` callback.
	/// - parameter token: A token that identifies a particular device to APNs.
	public class func didRegisterForRemoteNotificationsWithDeviceToken(_ token: Data) {
		// The app might call this method in other rare circumstances, such as when the user launches an app after having restored a device from data that is not the device’s backup data. In this exceptional case, the app won’t know the new device’s token until the user launches it. Thus we must persist this token as soon as we can so the SDK knows about it regardless of SDK's startup delays.
		MobileMessaging.sharedInstance?.didRegisterForRemoteNotificationsWithDeviceToken(token)
	}
	
	/// This method handles incoming remote notifications and triggers sending procedure for delivery reports. The method should be called from AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback.
	///
	/// - parameter userInfo: A dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
	/// - parameter completionHandler: A block to execute when the download operation is complete. The block is originally passed to AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback as a `fetchCompletionHandler` parameter. Mobile Messaging will execute this block after sending notification's delivery report.
	public class func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
		guard let mm = MobileMessaging.sharedInstance else {
			completionHandler(UIBackgroundFetchResult.failed)
			return
		}
		mm.didReceiveRemoteNotification(userInfo, completion: { result in
			completionHandler(result.backgroundFetchResult)
		})
	}
	
	/// This method is called when a running app receives a local notification. The method should be called from AppDelegate's `application(_:didReceiveLocalNotification:)` or `application(_:didReceive:)` callback.
	///
	/// - parameter notification: A local notification that encapsulates details about the notification, potentially including custom data.
	/// - parameter completion: A block to be executed when local notification handling is finished
	@available(iOS, deprecated: 10.0, message: "If your apps minimum deployment target is iOS 10 or later, you don't need to forward your App Delegate calls to this method. Handling local notifications on iOS since 10.0 is done by Mobile Messaging SDK by implementing UNUserNotificationCenterDelegate under the hood.")
	public class func didReceiveLocalNotification(_ notification: UILocalNotification, completion: (() -> Void)? = nil) {
		if let service = NotificationsInteractionService.sharedInstance, MMMessageHandler.isNotificationTapped(notification.userInfo as? [String: Any], applicationState: MobileMessaging.application.applicationState)
		{
			service.handleLocalNotificationTap(localNotification: notification, completion: completion)
		} else {
			completion?()
		}
	}
	
	/// Maintains attributes related to the current application installation such as APNs device token, badge number, etc.
	public class var currentInstallation: MMInstallation? {
		return MobileMessaging.sharedInstance?.currentInstallation
	}
	
	/// Returns the default message storage if used. For more information see `MMDefaultMessageStorage` class description.
	public class var defaultMessageStorage: MMDefaultMessageStorage? {
		return MobileMessaging.sharedInstance?.messageStorages[MessageStorageKind.messages.rawValue]?.adapteeStorage as? MMDefaultMessageStorage
	}
	
	/// Maintains attributes related to the current user such as unique ID for the registered user, email, MSISDN, custom data, external id.
	public class var currentUser: MMUser? {
		return MobileMessaging.sharedInstance?.currentUser
	}
	
	/// This method sets seen status for messages and sends a corresponding request to the server. If something went wrong, the library will repeat the request until it reaches the server.
	/// - parameter messageIds: Array of identifiers of messages that need to be marked as seen.
	public class func setSeen(messageIds: [String]) {
		guard let mm = MobileMessaging.sharedInstance else {
			return
		}
		mm.setSeen(messageIds)
	}
	
	/// This method sends mobile originated messages to the server.
	/// - parameter messages: Array of objects of `MOMessage` class that need to be sent.
	/// - parameter completion: The block to execute after the server responded, passes an array of `MOMessage` messages, that cont
	public class func sendMessages(_ messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		//TODO: make sharedInstance non optional in order to avoid such boilerplate and decrease places for mistake
		guard let mm = MobileMessaging.sharedInstance else {
			completion?(nil, NSError(type: MMInternalErrorType.UnknownError))
			return
		}
		mm.sendMessagesUserInitiated(messages, completion: completion)
	}
	
	/// An auxillary component provides the convinient access to the user agent data.
	public internal(set) static var userAgent = UserAgent()

	/// The `MessageHandlingDelegate` protocol defines methods for responding to actionable notifications and receiving new notifications. You assign your delegate object to the `messageHandlingDelegate` property of the `MobileMessaging` class. The MobileMessaging SDK calls methods of your delegate at appropriate times to deliver information.
	public static var messageHandlingDelegate: MessageHandlingDelegate? = nil
	
	/// The `URLSessionConfiguration` used for all url connections in the SDK
	///
	/// Default value is `URLSessionConfiguration.default`.
	/// You can provide your own configuration to define a custom NSURLProtocol, policies etc.
	public static var urlSessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default
	
	/// The `PrivacySettings` class incapsulates privacy settings that affect the SDK behaviour and business logic.
	public internal(set) static var privacySettings = PrivacySettings()
	
	/// Erases currently stored UserData associated with push registration along with messages in SDK storage.
	/// User's data synced over MobileMessaging is by default associated with created push registration. Logging out user means that push registration and device specific data will remain, but user's data (such as first name, custom data, ...) will be wiped out.
	/// If you log out user, there is no mechanism to log him in again since he's already subscribed for broadcast notifications from your app, but you might want to sync new user data to target this user specifically.
	/// - Remark: There is another version of logout method that doesn't require a `completion` parameter which means the SDK will handle any unsuccessful logout request by itself. See the method documentation for more details. Use this method in following cases:
	/// - you want to handle possible failures of server logout request and retry and maintain pending logout state by yourself
	/// - you're syncing user data to our server;
	/// - your application has logout option;
	/// - you don't want new logged in user to be targeted by other user's data, e.g. first name;
	/// - you want logged out user to still receive broadcast notifications (if not, you need to call MobileMessaging.disablePushRegistration()).
	/// - parameter completion: The block to execute after the logout procedure finished
	public class func logout(completion: @escaping (_ status: LogoutStatus, _ error: NSError?) -> Void) {
		//TODO: make sharedInstance non optional in order to avoid such boilerplate and decrease places for mistake
		guard let mm = MobileMessaging.sharedInstance else {
			completion(.undefined, NSError(type: MMInternalErrorType.UnknownError))
			return
		}
		mm.currentInstallation.logout(completion: completion)
	}

	/// Erases currently stored UserData associated with push registration along with messages in SDK storage.
	/// User's data synced over MobileMessaging is by default associated with created push registration. Logging out user means that push registration and device specific data will remain, but user's data (such as first name, custom data, ...) will be wiped out.
	/// If you log out user, there is no mechanism to log him in again since he's already subscribed for broadcast notifications from your app, but you might want to sync new user data to target this user specifically.
	/// - remark: There is another version of logout method that doesn't require a `completion` parameter which means the SDK will handle any unsuccessful logout request by itself. See the method documentation for more details. Use this method in following cases:
	/// - you don't need to hanlde networking failures and maintain pending logout state by yourself
	/// - you're syncing user data to our server;
	/// - your application has logout option;
	/// - you don't want new logged in user to be targeted by other user's data, e.g. first name;
	/// - you want logged out user to still receive broadcast notifications (if not, you need to call MobileMessaging.disablePushRegistration()).
	public class func logout() {
		guard let mm = MobileMessaging.sharedInstance else {
			return
		}
		mm.currentInstallation.logout(completion: { _, _ in})
	}
	
	//MARK: Internal
	static var sharedInstance: MobileMessaging?
	let userNotificationType: UserNotificationType
	let applicationCode: String
	var doRegisterToApns: Bool = true
	
	var storageType: MMStorageType = .SQLite
	let remoteAPIBaseURL: String
	
	class func withApplicationCode(_ code: String, notificationType: UserNotificationType, backendBaseURL: String, forceCleanup: Bool) -> MobileMessaging? {
		
		if let sharedInstance = sharedInstance, sharedInstance.applicationCode != code || sharedInstance.userNotificationType != notificationType || sharedInstance.remoteAPIBaseURL != backendBaseURL {
			MobileMessaging.stop()
		}
		sharedInstance = MobileMessaging(appCode: code, notificationType: notificationType, backendBaseURL: backendBaseURL, forceCleanup: forceCleanup)
		return sharedInstance
	}
	
	func sync() {
		currentInstallation.syncInstallationWithServer()
		performForEachSubservice { subservice in
			subservice.syncWithServer(nil)
		}
	}
	
	func doStart(_ completion: (() -> Void)? = nil) {
		MMLogDebug("Starting service (with apns registration=\(doRegisterToApns))...")

		self.startСomponents()
		
		self.performForEachSubservice {
			$0.mobileMessagingWillStart(self)
		}
		
		if self.doRegisterToApns == true {
			apnsRegistrationManager.registerForRemoteNotifications()
		}
		
		self.performForEachSubservice {
			$0.mobileMessagingDidStart(self)
		}
		
		completion?()
		
		MMLogDebug("Service started with subservices: \(self.subservices)")
	}
	
	/// - parameter clearKeychain: Bool, true by default, used in unit tests
	func cleanUpAndStop(_ clearKeychain: Bool = true) {
		cleanUp(clearKeychain)
		stop()
	}
	
	func cleanUp(_ clearKeychain: Bool = true) {
		MMLogDebug("Cleaning up MobileMessaging service...")
		if #available(iOS 10.0, *) {
			sharedNotificationExtensionStorage?.cleanupMessages()
		}
		MMCoreDataStorage.dropStorages(internalStorage: internalStorage, messageStorages: messageStorages)
		if (clearKeychain) {
			keychain.clear()
		}
		apnsRegistrationManager.cleanup()
	}
	
	func stop() {
		MMLogInfo("Stopping MobileMessaging service...")
		
		performForEachSubservice { subservice in
			subservice.mobileMessagingWillStop(self)
		}
		
		apnsRegistrationManager.unregister()
		
		messageStorages.values.forEach({$0.stop()})
		messageStorages.removeAll()
		
		performForEachSubservice { subservice in
			subservice.mobileMessagingDidStop(self)
		}
		
		MobileMessaging.messageHandlingDelegate = nil

		cleanupSubservices()
		
		// just to break retain cycles:
		apnsRegistrationManager = nil
		doRegisterToApns = true
		appListener = nil
		currentInstallation = nil
		currentUser = nil
		appListener = nil
		messageHandler = nil
		remoteApiProvider = nil

		keychain = nil
		sharedNotificationExtensionStorage = nil
		MobileMessaging.application = MainThreadedUIApplication()
		MobileMessaging.sharedInstance = nil
		if #available(iOS 10.0, *) {
			UNUserNotificationCenter.current().delegate = nil
		}
		MMLogInfo("MobileMessaging service stopped")
	}
	
	func didRegisterForRemoteNotificationsWithDeviceToken(_ token: Data, completion: ((NSError?) -> Void)? = nil) {
		apnsRegistrationManager.didRegisterForRemoteNotificationsWithDeviceToken(token, completion: completion)
	}
	
	func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], completion: ((MessageHandlingResult) -> Void)? = nil) {
		MMLogDebug("New remote notification received \(userInfo)")
		messageHandler.handleAPNSMessage(userInfo, completion: completion)
	}
	
	func updateRegistrationEnabledStatus(_ value: Bool, completion: ((NSError?) -> Void)? = nil) {
		currentInstallation.updateRegistrationEnabledStatus(value: value, completion: completion)
	}
	
	func updateRegistrationEnabledSubservicesStatus() {
		performForEachSubservice { subservice in
			subservice.pushRegistrationStatusDidChange(self)
		}
	}

	func updateLogoutStatusForSubservices() {
		performForEachSubservice { subservice in
			subservice.logoutStatusDidChange(self)
		}
	}
	
	func setSeen(_ messageIds: [String], completion: ((SeenStatusSendingResult) -> Void)? = nil) {
		MMLogDebug("Setting seen status: \(messageIds)")
		messageHandler.setSeen(messageIds, completion: completion)
	}

	func setSeenImmediately(_ messageIds: [String], completion: ((SeenStatusSendingResult) -> Void)? = nil) {
		MMLogDebug("Setting seen status immediately: \(messageIds)")
		messageHandler.setSeen(messageIds, immediately: true, completion: completion)
	}
	
	func sendMessagesSDKInitiated(_ messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		MMLogDebug("Sending mobile originated messages (SDK initiated)...")
		messageHandler.sendMessages(messages, isUserInitiated: false, completion: completion)
	}
	
	func retryMoMessageSending(completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		MMLogDebug("Retrying sending mobile originated messages...")
		messageHandler.sendMessages([], isUserInitiated: false, completion: completion)
	}
	
	func sendMessagesUserInitiated(_ messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		MMLogDebug("Sending mobile originated messages (User initiated)...")
		messageHandler.sendMessages(messages, isUserInitiated: true, completion: completion)
	}
	
	var isPushRegistrationEnabled: Bool {
		return currentInstallation.isPushRegistrationEnabled
	}
	
	func setAsPrimaryDevice(_ isPrimary: Bool, completion: ((NSError?) -> Void)? = nil) {
		currentInstallation.setAsPrimaryDevice(isPrimary, completion: completion)
	}
    
    func syncPrimarySettingWithServer(completion: @escaping ((_ isPrimary: Bool, _ error: NSError?) -> Void)) {
        currentInstallation.syncPrimarySettingWithServer(completion)
    }
	
	var isPrimaryDevice: Bool {
		get {
			return currentInstallation.isPrimaryDevice
		}
		set {
			currentInstallation.isPrimaryDevice = newValue
		}
	}
	
	var subservices: [String: MobileMessagingService] = [:]
	func registerSubservice(_ ss: MobileMessagingService) {
		subservices[ss.uniqueIdentifier] = ss
	}
	func cleanupSubservices() {
		subservices.removeAll()
	}
	
	func performForEachSubservice(_ block: (MobileMessagingService) -> Void) {
		subservices.values.forEach { subservice in
			block(subservice)
		}
	}

	//MARK: Private
	private init?(appCode: String, notificationType: UserNotificationType, backendBaseURL: String, forceCleanup: Bool) {
		
		let logCoreDataInitializationError = {
			MMLogError("Unable to initialize Core Data stack. MobileMessaging SDK service stopped because of the fatal error!")
		}

		guard var storage = try? MMCoreDataStorage.makeInternalStorage(self.storageType) else {
			logCoreDataInitializationError()
			return nil
		}
		
		if forceCleanup || applicationCodeChanged(storage: storage, newApplicationCode: appCode) {
			MMLogDebug("Data will be cleaned up due to the application code change.")
			MMCoreDataStorage.dropStorages(internalStorage: storage, messageStorages: messageStorages)
			do {
				storage = try MMCoreDataStorage.makeInternalStorage(self.storageType)
			} catch {
				logCoreDataInitializationError()
				return nil
			}
		}
		self.internalStorage        = storage
		self.applicationCode        = appCode
		self.userNotificationType   = notificationType
		self.remoteAPIBaseURL       = backendBaseURL
		if #available(iOS 10.0, *) {
			if let appGroupId = Bundle.mainAppBundle.appGroupId {
				self.appGroupId = appGroupId
				self.sharedNotificationExtensionStorage = DefaultSharedDataStorage(applicationCode: applicationCode, appGroupId: appGroupId)
			}
		}
		MobileMessaging.httpSessionManager = DynamicBaseUrlHTTPSessionManager(baseURL: URL(string: remoteAPIBaseURL), sessionConfiguration: MobileMessaging.urlSessionConfiguration, appGroupId: appGroupId)

		MMLogInfo("SDK successfully initialized!")
	}
	
	private func startСomponents() {
		if NotificationsInteractionService.sharedInstance == nil {
			NotificationsInteractionService.sharedInstance = NotificationsInteractionService(mmContext: self, categories: nil)
		}
		
		appListener = MMApplicationListener(mmContext: self)
		messageStorages.values.forEach({ $0.start() })
		
		if MobileMessaging.isPushRegistrationEnabled && currentInstallation.currentLogoutStatus == .undefined  {
			messageHandler.start()
		}
		
		if !isTestingProcessRunning {
			#if DEBUG
			VersionManager(mmContext: self).validateVersion()
			#endif
		}
	}
	
	var messageStorages: [String: MessageStorageQueuedAdapter] = [:]
	var messageStorageAdapter: MessageStorageQueuedAdapter?
	let internalStorage: MMCoreDataStorage
	lazy var coreDataProvider: CoreDataProvider = CoreDataProvider(storage: self.internalStorage)
	lazy var inMemoryDataProvider: InMemoryDataProvider = InMemoryDataProvider()
	lazy var currentInstallation: MMInstallation! = MMInstallation(inMemoryProvider: self.inMemoryDataProvider, coreDataProvider: self.coreDataProvider, storage: self.internalStorage, mmContext: self, applicationCode: self.applicationCode)
	lazy var currentUser: MMUser! = MMUser(inMemoryProvider: self.inMemoryDataProvider, coreDataProvider: self.coreDataProvider, mmContext: self)
	var appListener: MMApplicationListener!
	//TODO: continue decoupling. Move messageHandler to a subservice completely. (as GeofencingService)
	lazy var messageHandler: MMMessageHandler! = MMMessageHandler(storage: self.internalStorage, mmContext: self)
	lazy var apnsRegistrationManager: ApnsRegistrationManager! = ApnsRegistrationManager(mmContext: self)
	lazy var remoteApiProvider: RemoteAPIProvider! = RemoteAPIProvider()
	lazy var keychain: MMKeychain! = MMKeychain()

	//TODO: explicit unwrapping is a subject for removing
	static var httpSessionManager: DynamicBaseUrlHTTPSessionManager!
	static var reachabilityManagerFactory: () -> ReachabilityManagerProtocol = { return NetworkReachabilityManager() }
	static var application: MMApplication = MainThreadedUIApplication()
	static var date: MMDate = MMDate() // testability
	static var timeZone: TimeZone = TimeZone.current // for tests
	static var calendar: Calendar = Calendar.current // for tests
	var appGroupId: String?
	var sharedNotificationExtensionStorage: AppGroupMessageStorage?
	lazy var userNotificationCenterStorage: UserNotificationCenterStorage = DefaultUserNotificationCenterStorage()
	
	static let bundle = Bundle(for: MobileMessaging.self)
}

/// The `PrivacySettings` class incapsulates privacy settings that affect the SDK behaviour and business logic.
@objcMembers
public class PrivacySettings: NSObject {
	/// A boolean variable that indicates whether the MobileMessaging SDK will be sending the carrier information to the server.
	///
	/// Default value is `false`.
	public var carrierInfoSendingDisabled: Bool = false
	
	/// A boolean variable that indicates whether the MobileMessaging SDK will be sending the system information such as OS version, device model, application version to the server.
	///
	/// Default value is `false`.
	public var systemInfoSendingDisabled: Bool = false
	
	/// A boolean variable that indicates whether the MobileMessaging SDK will be persisting the application code locally. This feature is a convenience to maintain SDK viability during debugging and possible application code changes.
	///
	/// Default value is `false`.
	/// - Warning: there might be situation when you want to switch between different Application Codes during development/testing. If you disable the application code persisting (value `true`), the SDK won't detect the application code changes, thus won't cleanup the old application code related data. You should manually invoke `MobileMessaging.cleanUpAndStop()` prior to start otherwise the SDK would not detect the application code change.
	public var applicationCodePersistingDisabled: Bool = false
	
	/// A boolean variable that indicates whether the MobileMessaging SDK will be persisting the user data locally. Persisting user data locally gives you quick access to the data and eliminates a need to implement it yourself.
	///
	/// Default value is `false`.
	public var userDataPersistingDisabled: Bool = false
}
