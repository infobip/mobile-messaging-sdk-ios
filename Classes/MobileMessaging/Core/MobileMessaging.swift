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
public final class MobileMessaging: NSObject, NamedLogger {
    //MARK: Public
    
    /**
     Fabric method for Mobile Messaging session.
     - parameter code: The application code of your Application from Push Portal website.
     - parameter notificationType: Preferable notification types that indicating how the app alerts the user when a push notification arrives.
     */
    public class func withApplicationCode(_ code: String, notificationType: MMUserNotificationType) -> MobileMessaging? {
        return MobileMessaging(appCode: code, notificationType: notificationType, backendBaseURL: Consts.APIValues.prodDynamicBaseURLString)
    }
    
    /**
     Fabric method for Mobile Messaging session.
     - parameter code: The application code of your Application from Push Portal website.
     - parameter notificationType: Preferable notification types that indicating how the app alerts the user when a push notification arrives.
     - parameter forceCleanup: Defines whether the SDK must be cleaned up on startup.
     - warning: The cleanup (parameter `forceCleanup = true`) must be performed manually if you changed the application code while `PrivacySettings.applicationCodePersistingDisabled` is set to `true`.
     */
    @available(*, deprecated, message: "The function is deprecated. `forceCleanup` argument is always considered false, however we detect app code change and cleanup SDK data for you.")
    public class func withApplicationCode(_ code: String, notificationType: MMUserNotificationType, forceCleanup: Bool) -> MobileMessaging? {
        return MobileMessaging(appCode: code, notificationType: notificationType, backendBaseURL: Consts.APIValues.prodDynamicBaseURLString)
    }
    
    /**
     Fabric method for Mobile Messaging session.
     - parameter notificationType: Preferable notification types that indicating how the app alerts the user when a push notification arrives.
     - parameter code: The application code of your Application from Push Portal website.
     - parameter backendBaseURL: Your backend server base URL, optional parameter. Default is https://oneapi.infobip.com.
     */
    public class func withApplicationCode(_ code: String, notificationType: MMUserNotificationType, backendBaseURL: String) -> MobileMessaging? {
        return MobileMessaging(appCode: code, notificationType: notificationType, backendBaseURL: backendBaseURL)
    }
    
    /**
     Fabric method for Mobile Messaging session.
     It is possible to supply a default implementation of Message Storage to the Mobile Messaging library during initialization. In this case the library will save all received Push messages using the `MMDefaultMessageStorage`. Library can also be initialized either without message storage or with user-provided one (see `withMessageStorage(messageStorage:)`).
     */
    public func withDefaultMessageStorage() -> MobileMessaging {
        self.messageStorages[MessageStorageKind.messages.rawValue] = MessageStorageQueuedAdapter.makeDefaultMessagesStoragaAdapter()
        return self
    }
    
    /**
     Fabric method for Mobile Messaging session.
     It is possible to supply an implementation of Message Storage to the Mobile Messaging library during initialization. In this case the library will save all received Push messages to the supplied `messageStorage`. Library can also be initialized either without message storage or with the default message storage (see `withDefaultMessageStorage()` method).
     - parameter messageStorage: a storage object, that implements the `MessageStorage` protocol
     */
    public func withMessageStorage(_ messageStorage: MMMessageStorage) -> MobileMessaging {
        self.messageStorages[MessageStorageKind.messages.rawValue] = MessageStorageQueuedAdapter.makeMessagesStoragaAdapter(storage: messageStorage)
        return self
    }
    
    /**
     Fabric method for Mobile Messaging session.
     MobileMessaging SDK by default registers for remote notifications during `MobileMessaging.start()` procedure. It is possible to disable this default behavior. This might be needed in case your app should support other push notifications vendors in addition to (or instead of) Infobip's one, or you want to have a more flexible approach of when and where the user will be prompt to allow receiving Push Notifications.
     - remark: Don't forget to register for Push Notifications explicitly by calling `MobileMessaging.registerForRemoteNotifications()`.
     */
    public func withoutRegisteringForRemoteNotifications() -> MobileMessaging {
        registeringForRemoteNotificationsDisabled = true
        return self
    }
    
    /**
     Fabric method for Mobile Messaging session.
     Use this method to enable Full-featured In-App notifications (more about this feature - https://github.com/infobip/mobile-messaging-sdk-ios/wiki/In-app-notifications#full-featured-in-app-notifications)
     - remark: Without enabling Full-featured In-app notifications `MMNotificationMessageReceived` event is triggered, but In-App not processed and not displayed within WebView.
     */
    public func withFullFeaturedInApps() -> MobileMessaging {
        fullFeaturedInAppsEnabled = true
        return self
    }
    
    /**
     Fabric method for Mobile Messaging session.
     MobileMessaging SDK by default contains logic to unregister from Remote Notifications in certain cases: when depersonalization transitions to the pending state; when you explicitly stop MobileMessaging. It is possible to disable this default behavior. This might be needed in case your app should support other push notifications vendors in addition to (or instead of) Infobip's one.
     - remark: We don't recommend having multiple push notifications vendors functioning within the same application because they might collide and interfere with each other.
     */
    public func withoutUnregisteringForRemoteNotifications() -> MobileMessaging {
        unregisteringForRemoteNotificationsDisabled = true
        return self
    }
    
    /**
     Fabric method for Mobile Messaging session.
     It is possible to disable a Mobile Messaging default Notification Center Delegate implementation (UserNotificationCenterDelegate.swift:38). This might be needed in case your app should support other push notifications vendors in addition to (or instead of) Infobip's one. Implementing UNUserNotificationCenterDelegate protocol is required to handle user-selected actions from notifications, and to process notifications that arrive when your app is running in the foreground. (More details here https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)
     - remark: We don't recommend having multiple push notifications vendors functioning within the same application because they might collide and interfere with each other.
     */
    public func withoutOverridingNotificationCenterDelegate() -> MobileMessaging {
        overridingNotificationCenterDeleageDisabled = true
        return self
    }
    
    /**
     Asynchronously starts a new Mobile Messaging session.
     This method should be called form AppDelegate's `application(_:didFinishLaunchingWithOptions:)` callback.
     - remark: For now, Mobile Messaging SDK doesn't support Badge. You should handle the badge counter by yourself.
     */
    public func start(_ completion: (() -> Void)? = nil) {
        queue.async {
            if self.requiresRestart {
                self.requiresRestart = false
                self.doStop()
            }
            self.doStart()
            completion?()
        }
    }
    
    /**
     Asynchronously cleans up all persisted data.
     Use this method to completely drop any data persisted by the SDK (i.e. internal SDK data, optional user data, optional messages metadata).
     - parameter clearKeychain: defines whether the internalId in keychain will be cleaned. True by default.
     */
    public class func cleanUpAndStop(_ clearKeychain: Bool = true, completion: @escaping () -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.cleanUpAndStop(clearKeychain, completion: completion)
        } else {
            completion()
        }
    }
    
    /**
     Asynchronously stops all the currently running Mobile Messaging services.
     - parameter cleanUpData: defines whether the Mobile Messaging internal storage will be dropped. False by default.
     - attention: This function doesn't disable push notifications, they are still being received by the OS.
     */
    public class func stop(_ cleanUpData: Bool = false, completion: (() -> Void)? = nil) {
        if let mm = MobileMessaging.sharedInstance {
            if cleanUpData {
                mm.cleanUpAndStop(true, completion: completion ?? {})
            } else {
                mm.stop(completion ?? {})
            }
        } else {
            completion?()
        }
    }
    
    /** Call this method to initiate the registration process with Apple Push Notification service. User will be promt to allow receiving Push Notifications. */
    public class func registerForRemoteNotifications() {
        MobileMessaging.sharedInstance?.apnsRegistrationManager.registerForRemoteNotifications(userInitiated: true)
    }
    
    /**
     Logging utility is used for:
     - setting up the logging options and logging levels.
     - obtaining a path to the logs file in case the Logging utility is set up to log in file (logging options contains `.file` option).
     */
    public static var logger: MMLogging? = (MMLoggerFactory() as MMLoggerFactoryProtocol).createLogger?()
    
    /**
     This method handles a new APNs device token and updates user's registration on the server.
     This method should be called form AppDelegate's `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` callback.
     - parameter token: A token that identifies a particular device to APNs.
     */
    public class func didRegisterForRemoteNotificationsWithDeviceToken(_ token: Data) {
        // The app might call this method in other rare circumstances, such as when the user launches an app after having restored a device from data that is not the device’s backup data. In this exceptional case, the app won’t know the new device’s token until the user launches it. Thus we must persist this token as soon as we can so the SDK knows about it regardless of SDK's startup delays.
        MobileMessaging.sharedInstance?.queue.async {
            MobileMessaging.sharedInstance?.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: false, token: token) { _ in }
        }
    }
    
    /**
     This method handles incoming remote notifications and triggers sending procedure for delivery reports. The method should be called from AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback.
     - parameter userInfo: A dictionary that contains information related to the remote notification, potentially including a badge number for the app icon, an alert sound, an alert message to display to the user, a notification identifier, and custom data.
     - parameter completionHandler: A block to execute when the download operation is complete. The block is originally passed to AppDelegate's `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` callback as a `fetchCompletionHandler` parameter. Mobile Messaging will execute this block after sending notification's delivery report.
     */
    public class func didReceiveRemoteNotification(_ userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.didReceiveRemoteNotification(userInitiated: false, userInfo: userInfo, completion: { result in
                    completionHandler(result.backgroundFetchResult)
                })
            }
        } else {
            completionHandler(UIBackgroundFetchResult.failed)
        }
    }
    
    /** Returns the default message storage if used. For more information see `MMDefaultMessageStorage` class description. */
    public class var defaultMessageStorage: MMDefaultMessageStorage? {
        return MobileMessaging.sharedInstance?.messageStorages[MessageStorageKind.messages.rawValue]?.adapteeStorage as? MMDefaultMessageStorage
    }
    
    /**
     Synchronously retrieves current installation data such as APNs device token, badge number, etc.
     
     For more information and examples see: [Users and installations](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations)
     */
    public class func getInstallation() -> MMInstallation? {
        return MobileMessaging.sharedInstance?.dirtyInstallation()
    }
    
    /**
     Synchronously retrieves current user data such as unique push registration id for the registered user, emails, phones, custom data, external user id, etc.
     
     For more information and examples see: [Users and installations](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations)
     */
    public class func getUser() -> MMUser? {
        return MobileMessaging.sharedInstance?.dirtyUser()
    }
    
    /**
     Asynchronously fetches the user data from the server.
     
     For more information and examples see: [User profile](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/User-profile)
     - parameter completion: The block to execute after the server responded.
     - parameter user: Fetched user. Contains actual data if not error happened.
     - parameter error: Optional error.
     */
    public class func fetchUser(completion: @escaping (_ user: MMUser?, _ error: NSError?) -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.userService.fetchFromServer(userInitiated: true) { (fetched, error) in
                    completion(fetched, error)
                }
            }
        } else {
            completion(nil, NSError(type: .MobileMessagingInstanceNotInitialized))
        }
    }
    
    /**
     Asynchronously fetches the installation data from the server.
     
     For more information and examples see: [Users and installations](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations)
     - parameter completion: The block to execute after the server responded.
     - parameter installation: Fetched installation. Contains actual data if not error happened.
     - parameter error: Optional error.
     */
    public class func fetchInstallation(completion: @escaping (_ installation: MMInstallation?, _ error: NSError?) -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.installationService.fetchFromServer(userInitiated: true) { (fetched, error) in
                    completion(fetched, error)
                }
            }
        } else {
            completion(nil, NSError(type: .MobileMessagingInstanceNotInitialized))
        }
    }
    
    /**
     Asynchronously saves changed user data on the server.
     
     For more information and examples see: [User profile](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/User-profile)
     - parameter user: User data to save on server.
     - parameter completion: The block to execute after the server responded.
     - parameter error: Optional error.
     */
    public class func saveUser(_ user: MMUser, completion: @escaping (_ error: NSError?) -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.userService.save(userInitiated: true, userData: user, completion: completion)
            }
        } else {
            completion(NSError(type: .MobileMessagingInstanceNotInitialized))
        }
    }
    
    /**
     Asynchronously saves changed installation (registration data, custom installation attributes abd system data) on the server.
     
     For more information and examples see: [Users and installations](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations)
     - parameter installation: Installation data to save on server.
     - parameter completion: The block to execute after the server responded.
     - parameter error: Optional error.
     */
    public class func saveInstallation(_ installation: MMInstallation, completion: @escaping (_ error: NSError?) -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.installationService.save(userInitiated: true, installationData: installation, completion: completion)
            }
        } else {
            completion(NSError(type: .MobileMessagingInstanceNotInitialized))
        }
    }
    
    /**
     Synchronously persists user data to the disk. Pivacy settings are applied according to `MobileMessaging.privacySettings` settings.
     
     For more information and examples see: [Users and installations](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations)
     - parameter user: User data to persist.
     */
    public class func persistUser(_ user: MMUser) {
        user.archiveDirty()
    }
    
    /**
     Synchronously persists installation data to the disk. Pivacy settings are applied according to `MobileMessaging.privacySettings` settings.
     
     For more information and examples see: [Users and installations](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations)
     */
    public class func persistInstallation(_ installation: MMInstallation) {
        installation.archiveDirty()
    }
    
    // MARK: - Personalize/Depersonalize
    
    /**
     Asynchronously ereases currently persisted user data associated with push registration along with messages in SDK storage.
     User's data synced over MobileMessaging is by default associated with created push registration. Depersonalizing an installation means that a push registration and device specific data will remain, but user's data (such as first name, custom data, ...) will be wiped out.
     If you depersonalize an installation from person, there is a way to personalize it again by providing new user data (either by UserDataService data setters or `InstallationDataService.personalize()` method) in order to target this user specifically.
     - Remark: There is another version of depersonalize method that doesn't require a `completion` parameter which means the SDK will handle any unsuccessful depersonalize request by itself. See the method documentation for more details. Use this method in following cases:
     - you want to handle possible failures of server depersonalize request, retry and maintain pending depersonalize state by yourself
     - you're syncing user data to our server;
     - your application has logout functionality;
     - you don't want new personalized installation to be targeted by other user's data, e.g. first name;
     - you want depersonalized installation from user and still be able to receive broadcast notifications (otherwise, you need to disable push registration via Installation.isPushRegistrationEnabled).
     
     For more information and examples see: [Users and installations](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations)
     - parameter completion: The block to execute after the server responded.
     - parameter status: Current depersonalization status.
     - parameter error: Optional error.
     */
    public class func depersonalize(completion: @escaping (_ status: MMSuccessPending, _ error: NSError?) -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.installationService.depersonalize(userInitiated: true, completion: completion)
            }
        } else {
            completion(MMSuccessPending.undefined, NSError(type: .MobileMessagingInstanceNotInitialized))
        }
    }
    
    /**
     Asynchronously personalizes current installation with a person on the server.
     Each user can have Phone numbers, Emails and External user ID. These fields are unique identifiers of a user profile on Infobip platform and provide capability to personalize any app installation with a user profile. The platform provides data grouping functions based on these parameters. For example, if two installations of a particular app will try to save the same Phone number, then both of them will be collected under a single user. Phone number, Email and External user ID are also widely used when targeting users with messages across different channels via Infobip platform.
     - remark: This API doesn't depersonalize current installation from any person that it may be currently personalized with. In order to depersonalize current possible person from current installation and personalize it with another person at once, use another API:
     ```
     MobileMessaging.personalize(forceDepersonalize: true, userIdentity: userAttributes: completion:)
     ```
     
     For more information and examples see: [Users and installations](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations)
     - parameter userIdentity: A combination of phones, emails and an external user id that will form a unique key for a person.
     - parameter userAttributes: Optional user data to be saved for the person.
     - parameter completion: The block to execute after the server responded.
     - parameter error: Optional error. */
    public class func personalize(withUserIdentity identity: MMUserIdentity, userAttributes: MMUserAttributes?, completion: @escaping (_ error: NSError?) -> Void) {
        personalize(forceDepersonalize: false, userIdentity: identity, userAttributes: userAttributes, completion: completion)
    }
    
    /**
     Asynchronously personalizes current installation with a person on the server.
     Each user can have Phone numbers, Emails and External user ID. These fields are unique identifiers of a user profile on Infobip platform and provide capability to personalize any app installation with a user profile. The platform provides data grouping functions based on these parameters. For example, if two installations of a particular app will try to save the same Phone number, then both of them will be collected under a single user. Phone number, Email and External user ID are also widely used when targeting users with messages across different channels via Infobip platform.
     
     For more information and examples see: [Users and installations](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations)
     - parameter forceDepersonalize: Determines whether or not the depersonalization should be performed on our server in order to depersonalize the installation from previous user profile.
     - parameter userIdentity: A combination of phones, emails and an external user id that will form a unique key for a person.
     - parameter userAttributes: Optional user data to be saved for the person.
     - parameter completion: The block to execute after the server responded.
     - parameter error : Optional error. */
    public class func personalize(forceDepersonalize: Bool, userIdentity: MMUserIdentity, userAttributes: MMUserAttributes?, completion: @escaping (_ error: NSError?) -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.userService.personalize(userInitiated: true, forceDepersonalize: forceDepersonalize, userIdentity: userIdentity, userAttributes: userAttributes, completion: completion)
            }
        } else {
            completion(NSError(type: .MobileMessagingInstanceNotInitialized))
        }
    }
    
    /**
     Asynchronously sets a current users arbitrary installation as primary.
     
     For more information and examples see: [Users and installations](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations)
     - parameter pushRegId: Push Registration Id of the installation to be updated.
     - parameter primary: New primary value.
     - parameter completion: The block to execute after the server responded.
     - parameter installations: A list of installations. Contains actual data if no error happened.
     - parameter error: Optional error.
     */
    public class func setInstallation(withPushRegistrationId pushRegId: String, asPrimary primary: Bool, completion: @escaping (_ installations: [MMInstallation]?, _ error: NSError?) -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.userService.setInstallation(withPushRegistrationId: pushRegId, asPrimary: primary, completion: completion)
            }
        } else {
            completion(nil, NSError(type: .MobileMessagingInstanceNotInitialized))
        }
    }
    
    /**
     Asynchronously depersonalizes current users arbitrary installation from the current user.
     
     For more information and examples see: [Users and installations](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations)
     - parameter pushRegId: Push Registration Id of the installation to be depersonalized.
     - parameter completion: The block to execute after the server responded.
     - parameter installations: A list of installations. Contains actual data if no error happened.
     - parameter error: Optional error.
     */
    public class func depersonalizeInstallation(withPushRegistrationId pushRegId: String, completion: @escaping (_ installations: [MMInstallation]?, _ error: NSError?) -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.userService.depersonalizeInstallation(userInitiated: true, withPushRegistrationId: pushRegId, completion: completion)
            }
        } else {
            completion(nil, NSError(type: .MobileMessagingInstanceNotInitialized))
        }
    }
    
    /**
     Asynchronously fetches all installations personalized with the current user.
     
     For more information and examples see: [Users and installations](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Users-and-installations)
     - parameter completion: The block to execute after the server responded.
     - parameter installations: A list of fetched installations. Contains actual data if no error happened.
     - parameter error: Optional error.
     */
    public class func fetchInstallations(completion: @escaping (_ installations: [MMInstallation]?, _ error: NSError?) -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.userService.fetchFromServer(userInitiated: true) { (user, error) in
                    completion(user.installations, error)
                }
            }
        } else {
            completion(nil, NSError(type: .MobileMessagingInstanceNotInitialized))
        }
    }
    
    /**
     Asynchronously sets seen status for messages and sends a corresponding request to the server. If something went wrong, the library will repeat the request until it reaches the server.
     - parameter messageIds: Array of identifiers of messages that need to be marked as seen.
     - parameter completion: The block to execute after the seen status "SeenNotSent" is persisted. Synchronization with the server will be performed eventually.
     */
    public class func setSeen(messageIds: [String], completion: @escaping () -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.setSeen(userInitiated: true, messageIds: messageIds, immediately: false, completion: completion)
            }
        } else {
            completion()
        }
    }
    
    /**
     Asynchronously sends mobile originated messages to the server.
     - parameter messages: Array of objects of `MM_MOMessage` class that need to be sent.
     - parameter completion: The block to execute after the server responded, passes an array of `MM_MOMessage` messages
     - parameter messages: List of messages sent if no error happened
     - parameter error: Optional error
     */
    public class func sendMessages(_ messages: [MM_MOMessage], completion: @escaping (_ messages: [MM_MOMessage]?, _ error: NSError?) -> Void) {
        //TODO: make sharedInstance non optional in order to avoid such boilerplate and decrease places for mistake
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.sendMessagesUserInitiated(messages, completion: completion)
            }
        } else {
            completion(nil, NSError(type: .MobileMessagingInstanceNotInitialized))
        }
    }
    
    /** An auxillary component provides the convinient access to the user agent data. */
    public internal(set) static var userAgent = MMUserAgent()
    
    /**
     The `MessageHandlingDelegate` protocol defines methods for responding to actionable notifications and receiving new notifications. You assign your delegate object to the `messageHandlingDelegate` property of the `MobileMessaging` class. The MobileMessaging SDK calls methods of your delegate at appropriate times to deliver information. */
    public static var messageHandlingDelegate: MMMessageHandlingDelegate? = nil
    
    /**
     The `URLSessionConfiguration` used for all url connections in the SDK
     Default value is `URLSessionConfiguration.default`.
     You can provide your own configuration to define a custom NSURLProtocol, policies etc.
     */
    public static var urlSessionConfiguration: URLSessionConfiguration = URLSessionConfiguration.default
    
    /** The `MMPrivacySettings` class encapsulates privacy settings that affect the SDK behaviour and business logic. */
    public internal(set) static var privacySettings = MMPrivacySettings()
    
    /** The number currently set as the badge of the app icon in Springboard.
     Set to 0 (zero) to hide the badge number. The default value of this property is 0. */
    public static var badgeNumber: Int {
        get {
            let fact = MobileMessaging.application.applicationIconBadgeNumber
            InternalData.modifyCurrent { (data) in
                data.badgeNumber = fact
            }
            return fact
        }
        set {
            MobileMessaging.application.applicationIconBadgeNumber = newValue
            InternalData.modifyCurrent { (data) in
                data.badgeNumber = newValue
            }
        }
    }
    
    /**
     Asynchronously submits a custom event and immediately sends it to the server. If any connection error occured or the server responded with "Bad request" error, you have to handle the error yourself, perform retries if needed.
     - parameter customEvent: Custom event to be sent to the server.
     - parameter completion: The block to execute after the server responded.
     - parameter error: Optional error.
     */
    public class func submitEvent(_ customEvent: MMCustomEvent, completion: @escaping (_ error: NSError?) -> Void) {
        if let mm = MobileMessaging.sharedInstance {
            mm.queue.async {
                mm.eventsService.submitEvent(customEvent: customEvent, reportImmediately: true, completion: completion)
            }
        } else {
            completion(NSError(type: .MobileMessagingInstanceNotInitialized))
        }
    }
    
    /**
     Asynchronously submits the custom event and sends it to the server eventually. If something went wrong during the communication with the server, the request will be retied until the event succesfully accepted.
     - parameter customEvent: Custom event to be sent to the server.
     */
    public class func submitEvent(_ customEvent: MMCustomEvent) {
        MobileMessaging.sharedInstance?.queue.async {
            MobileMessaging.sharedInstance?.eventsService.submitEvent(customEvent: customEvent, reportImmediately: false, completion: {_ in})
        }
    }
    
    /**
     You can define your own custom appearance for in-app webView, which will appear if user taps on push notification, by accessing a webView settings object.
     */
    public let webViewSettings: MMWebViewSettings = MMWebViewSettings.sharedInstance
    
    /**
     Displays `MODAL` in-app notification for provided message, if message isn't expired.
     - parameter message: `MM_MTMessage` object.
     */
    public class func showModalInAppNotification(forMessage message: MM_MTMessage) {
        MobileMessaging.sharedInstance?.interactiveAlertManager.showModalNotificationManually(forMessage: message)
    }
    
    //MARK: Internal
    public static var sharedInstance: MobileMessaging?
    public let userNotificationType: MMUserNotificationType
    public let applicationCode: String
    var registeringForRemoteNotificationsDisabled: Bool = false
    var fullFeaturedInAppsEnabled: Bool = false
    var overridingNotificationCenterDeleageDisabled: Bool = false
    var unregisteringForRemoteNotificationsDisabled: Bool = false
    var storageType: MMStorageType = .SQLite
    let remoteAPIBaseURL: String
    
    func doStart() {
        if appCodeChanged {
            Self.logDebug("Data will be cleaned up due to the application code change.")
            appCodeChanged = false
            MobileMessaging.doCleanUp(false)
            do {
                self.internalStorage = try MMCoreDataStorage.makeInternalStorage(self.storageType)
            } catch {
                MobileMessaging.logCoreDataInitializationError()
                return
            }
        }
        
        self.logDebug("Starting service (with apns registration disabled=\(self.registeringForRemoteNotificationsDisabled), apns unregistering disabled=\(self.unregisteringForRemoteNotificationsDisabled), notification center delegate disabled=\(self.overridingNotificationCenterDeleageDisabled))...")
        
        let ci = InternalData.unarchiveCurrent()
        ci.applicationCode = self.applicationCode
        ci.applicationCodeHash = calculateAppCodeHash(self.applicationCode)
        ci.archiveCurrent()
        
        self.startComponents()
        NotificationCenter.default.post(name: Notification.Name.init("mobileMessagingWillStart"), object: self)
        self.apnsRegistrationManager.registerForRemoteNotifications(userInitiated: false)
        NotificationCenter.default.post(name: Notification.Name.init("mobileMessagingDidStart"), object: self)
        self.logDebug("Service started with subservices: \(self.subservices)")
    }
    
    func cleanUpAndStop(_ clearKeychain: Bool = true, completion: @escaping () -> Void) {
        queue.async {
            self.doCleanupAndStop(clearKeychain)
            completion()
        }
    }
    
    func doCleanupAndStop(_ clearKeychain: Bool = true) {
        MobileMessaging.doCleanUp(clearKeychain)
        self.doStop()
    }
    
    class func doCleanUp(_ clearKeychain: Bool = true) {
        self.logDebug("Cleaning up MobileMessaging service...")
        if let mm = MobileMessaging.sharedInstance {
            mm.sharedNotificationExtensionStorage?.cleanupMessages()
            mm.httpSessionManager?.resetBaseUrl()
            
            MMCoreDataStorage.dropStorages(internalStorage: mm.internalStorage, messageStorages: mm.messageStorages)
            
            if (clearKeychain) {
                mm.keychain.clear()
            }
            mm.apnsRegistrationManager.cleanup()
        }
        
        
        InternalData.resetCurrent()
        MMUser.resetAll()
        MMInstallation.resetAll()
    }
    
    func stop(_ completion: @escaping () -> Void) {
        queue.async {
            self.doStop()
            completion()
        }
    }
    
    func doStop() {
        logInfo("Stopping MobileMessaging service...")
        NotificationCenter.default.post(name: Notification.Name.init("mobileMessagingWillStop"), object: self)
        
        apnsRegistrationManager.stop()
        
        let dispatchGroup = DispatchGroup()
        performForEachSubservice { subservice in
            dispatchGroup.enter()
            subservice.stopService({ _ in
                dispatchGroup.leave()
            })
        }
        dispatchGroup.wait()
        
        messageStorages.values.forEach({$0.stop()})
        messageStorages.removeAll()
        
        MobileMessaging.messageHandlingDelegate = nil
        
        cleanupSubservices()
        
        // just to break retain cycles:
        apnsRegistrationManager = nil
        registeringForRemoteNotificationsDisabled = false
        overridingNotificationCenterDeleageDisabled = false
        messageHandler = nil
        remoteApiProvider = nil
        userSessionService = nil
        installationService = nil
        userService = nil
        eventsService = nil
        baseUrlManager = nil
        notificationsInteractionService = nil
        httpSessionManager = nil
        InternalData.cached.reset()
        
        keychain = nil
        sharedNotificationExtensionStorage = nil
        MobileMessaging.application = MainThreadedUIApplication()
        MobileMessaging.sharedInstance = nil
        logInfo("MobileMessaging service stopped")
    }
    
    func didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: Bool, token: Data, completion: @escaping (NSError?) -> Void) {
        self.apnsRegistrationManager.didRegisterForRemoteNotificationsWithDeviceToken(userInitiated: userInitiated, token: token, completion: completion)
    }
    
    func didReceiveRemoteNotification(userInitiated: Bool, userInfo: [AnyHashable : Any], completion: @escaping (MessageHandlingResult) -> Void) {
        logDebug("New remote notification received \(userInfo)")
        messageHandler.handleAPNSMessage(userInitiated: userInitiated, userInfo: userInfo, completion: completion)
    }
    
    func updateRegistrationEnabledSubservicesStatus() {
        NotificationCenter.default.post(name: Notification.Name.init("pushRegistrationStatusDidChange"), object: self)
    }
    
    func updateDepersonalizeStatusForSubservices() {
        NotificationCenter.default.post(name: Notification.Name.init("depersonalizationStatusDidChange"), object: self)
    }
    
    func baseUrlDidChange() {
        NotificationCenter.default.post(name: Notification.Name.init("baseUrlDidChange"), object: self)
    }
    
    func setSeen(userInitiated: Bool, messageIds: [String], immediately: Bool, completion: @escaping () -> Void) {
        logDebug("Setting seen status: \(messageIds), immediately \(immediately)")
        messageHandler.setSeen(userInitiated: userInitiated, messageIds: messageIds, immediately: immediately, completion: completion)
    }
    
    func sendMessagesSDKInitiated(_ messages: [MM_MOMessage], completion: @escaping ([MM_MOMessage]?, NSError?) -> Void) {
        logDebug("Sending mobile originated messages (SDK initiated)...")
        messageHandler.sendMessages(messages: messages, isUserInitiated: false, completion: completion)
    }
    
    func retryMoMessageSending(completion: @escaping ([MM_MOMessage]?, NSError?) -> Void) {
        logDebug("Retrying sending mobile originated messages...")
        messageHandler.sendMessages(messages: [], isUserInitiated: false, completion: completion)
    }
    
    func sendMessagesUserInitiated(_ messages: [MM_MOMessage], completion: @escaping ([MM_MOMessage]?, NSError?) -> Void) {
        logDebug("Sending mobile originated messages (User initiated)...")
        messageHandler.sendMessages(messages: messages, isUserInitiated: true, completion: completion)
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
    
    internal init?(appCode: String, notificationType: MMUserNotificationType, backendBaseURL: String, internalStorage: MMCoreDataStorage? = nil) {
        
        NSKeyedUnarchiver.mm_setMappingForRenamedClasses()
        
        guard let storage = internalStorage == nil ? try? MMCoreDataStorage.makeInternalStorage(self.storageType) : internalStorage else {
            MobileMessaging.logCoreDataInitializationError()
            return nil
        }
        
        if let sharedInstance = MobileMessaging.sharedInstance, sharedInstance.applicationCode != appCode || sharedInstance.userNotificationType != notificationType || sharedInstance.remoteAPIBaseURL != backendBaseURL {
            requiresRestart = true
        }
        
        if applicationCodeChanged(newApplicationCode: appCode) {
            appCodeChanged = true
        }
        self.internalStorage = storage
        self.applicationCode = appCode
        self.userNotificationType = notificationType
        self.remoteAPIBaseURL = backendBaseURL
        self.appGroupId = Bundle.mainAppBundle.appGroupId
        
        super.init()
        MobileMessaging.sharedInstance = self
        logInfo("SDK successfully initialized!")
    }
    
    private func startComponents() {
        if let appGroupId = appGroupId, sharedNotificationExtensionStorage == nil {
            sharedNotificationExtensionStorage = DefaultSharedDataStorage(applicationCode: applicationCode, appGroupId: appGroupId)
        }
        if notificationsInteractionService == nil {
            notificationsInteractionService = NotificationsInteractionService(mmContext: self, categories: nil)
        }
        baseUrlManager = BaseUrlManager(mmContext: self)
        userSessionService = UserSessionService(mmContext: self)
        userService = UserDataService(mmContext: self)
        eventsService = EventsService(mmContext: self)
        installationService = InstallationDataService(mmContext: self)
        messageStorages.values.forEach({ $0.start() })
        
        let currentInstall = currentInstallation()
        if currentInstall.isPushRegistrationEnabled && internalData().currentDepersonalizationStatus == .undefined  {
            messageHandler.start({ _ in })
        } else {
            logDebug("messageHandler didn't start: reg enabled \(currentInstall.isPushRegistrationEnabled), depersonalizaton status \(internalData().currentDepersonalizationStatus.rawValue)")
        }
        
        if !isTestingProcessRunning {
#if DEBUG
            VersionManager(mmContext: self).validateVersion()
#endif
        }
    }
    
    var messageStorages: [String: MessageStorageQueuedAdapter] = [:]
    var messageStorageAdapter: MessageStorageQueuedAdapter?
    
    public var internalStorage: MMCoreDataStorage
    
    public func internalData() -> InternalData { return InternalData.unarchiveCurrent() }
    public func currentInstallation() -> MMInstallation { return MMInstallation.unarchiveCurrent() }
    func currentUser() -> MMUser { return MMUser.unarchiveCurrent() }
    
    func dirtyInstallation() -> MMInstallation { return MMInstallation.unarchiveDirty() }
    func dirtyUser() -> MMUser { return MMUser.unarchiveDirty().copy() as! MMUser }
    
    public func resolveInstallation() -> MMInstallation { return dirtyInstallation() }
    func resolveUser() -> MMUser { return dirtyUser() }
    var userService: UserDataService!
    var installationService: InstallationDataService!
    var userSessionService: UserSessionService!
    var baseUrlManager: BaseUrlManager!
    var eventsService: EventsService!
    var notificationsInteractionService: NotificationsInteractionService?
    
    
    public lazy var messageHandler: MMMessageHandler! = MMMessageHandler(storage: self.internalStorage, mmContext: self)
    lazy var apnsRegistrationManager: ApnsRegistrationManager! = ApnsRegistrationManager(mmContext: self)
    public lazy var remoteApiProvider: RemoteAPIProvider! = {
        return RemoteAPIProvider(sessionManager: self.httpSessionManager)
    }()
    lazy var keychain: MMKeychain! = MMKeychain()
    lazy var interactiveAlertManager: InteractiveMessageAlertManager! = InteractiveMessageAlertManager.sharedInstance
    public lazy var httpSessionManager: DynamicBaseUrlHTTPSessionManager! = DynamicBaseUrlHTTPSessionManager(baseURL: URL(string: remoteAPIBaseURL)!, sessionConfiguration: MobileMessaging.urlSessionConfiguration, appGroupId: appGroupId)
    
    public static var application: MMApplication = MainThreadedUIApplication()
    public static var date: MMDate = MMDate() // testability
    public static var timeZone: TimeZone = TimeZone.current // for tests
    public static var calendar: Calendar = Calendar.current // for tests
    var appGroupId: String?
    var sharedNotificationExtensionStorage: AppGroupMessageStorage?
    lazy var userNotificationCenterStorage: UserNotificationCenterStorage = DefaultUserNotificationCenterStorage()
    
    static let bundle = Bundle(for: MobileMessaging.self)
    static let resourceBundle: Bundle = {
        #if SWIFT_PACKAGE
            return Bundle.module
        #else
            guard let resourceBundleURL = MobileMessaging.bundle.url(forResource: "MMCore", withExtension: "bundle"),
                  let result = Bundle(url: resourceBundleURL) else {
                //in case of Carthage usage, MobileMessaging bundle will be used for getting resources
                return MobileMessaging.bundle
            }
            return result
        #endif
    }()
    
    let queue = DispatchQueue(label: "com.mobile-messaging.queue.concurrent.main")
    
    fileprivate class func logCoreDataInitializationError() {
        Self.logError("Unable to initialize Core Data stack. MobileMessaging SDK service stopped because of the fatal error!")
    }
    private var appCodeChanged = false
    private var requiresRestart = false
}
