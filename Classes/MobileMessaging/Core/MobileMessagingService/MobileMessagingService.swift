//
//  MobileMessagingService.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 26.10.2021.
//

import Foundation

open class MobileMessagingService: NSObject, NamedLogger {
    public let mmContext: MobileMessaging
    let uniqueIdentifier: String
    open var isRunning: Bool
    
    public init(mmContext: MobileMessaging, uniqueIdentifier: String) {
        self.isRunning = false
        self.mmContext = mmContext
        self.uniqueIdentifier = uniqueIdentifier
        super.init()
        self.mmContext.registerSubservice(self)
        setupSDKObserving()
    }
    
    deinit {
        stopObserving()
    }
    
    open func start(_ completion: @escaping (Bool) -> Void) {
        guard isRunning == false else {
            completion(isRunning)
            return
        }
        logDebug("starting")
        isRunning = true
        setupAppStateObserving()
        completion(isRunning)
    }
    
    open func suspend() {
        logDebug("stopping")
        stopAppStateObserving()
        isRunning = false
    }
    
    open func stopService(_ completion: @escaping (Bool) -> Void) {
        suspend()
        NotificationCenter.default.removeObserver(self)
        dispatchGroup.wait()
        completion(isRunning)
    }
    
    /// A system data that is related to a particular subservice. For example for Geofencing service it is a key-value pair "geofencing: <bool>" that indicates whether the service is enabled or not
    open var systemData: [String: AnyHashable]? { return nil }
    
    /// Called by message handling operation in order to fill the MessageManagedObject data by MobileMessaging subservices. Subservice must be in charge of fulfilling the message data to be stored on disk. You return `true` if message was changed by the method.
    open func populateNewPersistedMessage(_ message: inout MessageManagedObject, originalMessage: MM_MTMessage) -> Bool { return false }
    open func handleNewMessage(_ message: MM_MTMessage, completion: @escaping (MessageHandlingResult) -> Void) { completion(.noData) }
    open func handleAnyMessage(_ message: MM_MTMessage, completion: @escaping (MessageHandlingResult) -> Void) { completion(.noData) }
    
    var dispatchGroup = DispatchGroup()
    
    open func pushRegistrationStatusDidChange(_ completion: @escaping () -> Void) { completion() }
    open func depersonalizationStatusDidChange(_ completion: @escaping () -> Void) { completion() }
    open func mobileMessagingWillStart(_ completion: @escaping () -> Void) { completion() }
    open func mobileMessagingDidStart(_ completion: @escaping () -> Void) { completion() }
    func mobileMessagingWillStop(_ completion: @escaping () -> Void) { completion() }
    open func appWillEnterForeground(_ completion: @escaping () -> Void) { completion() }
    open func appDidFinishLaunching(_ notification: Notification, completion: @escaping () -> Void) { completion() }
    open func appDidBecomeActive(_ completion: @escaping () -> Void) { completion() }
    func appWillResignActive(_ completion: @escaping () -> Void) { completion() }
    func appWillTerminate(_ completion: @escaping () -> Void) { completion() }
    open func appDidEnterBackground(_ completion: @escaping () -> Void) { completion() }
    func geoServiceDidStart(_ completion: @escaping () -> Void) { completion() }
    func baseUrlDidChange(_ completion: @escaping () -> Void) { completion() }
    
    func submitToDispatchGroup(block: @escaping (@escaping () -> Void) -> Void) {
        dispatchGroup.enter()
        block() {
            self.dispatchGroup.leave()
        }
    }
    
    @objc private func pushRegistrationStatusDidChange(notification: Notification) { submitToDispatchGroup(block: pushRegistrationStatusDidChange) }
    @objc private func depersonalizationStatusDidChange(notification: Notification) { submitToDispatchGroup(block: depersonalizationStatusDidChange) }
    @objc private func mobileMessagingWillStart(notification: Notification) { submitToDispatchGroup(block: mobileMessagingWillStart) }
    @objc private func mobileMessagingDidStart(notification: Notification) { submitToDispatchGroup(block: mobileMessagingDidStart) }
    @objc private func mobileMessagingWillStop(notification: Notification) { submitToDispatchGroup(block: mobileMessagingWillStop) }
    @objc private func baseUrlDidChange(notification: Notification) { submitToDispatchGroup(block: baseUrlDidChange) }
    
    @objc private func appWillEnterForegroundMainThread(notification: Notification) {
        submitToDispatchGroup(block: { completion in
            self.mmContext.queue.async {self.appWillEnterForeground(completion)}
        })
    }
    @objc private func appDidBecomeActiveMainThread(notification: Notification) {
        submitToDispatchGroup(block: { completion in
            self.mmContext.queue.async {self.appDidBecomeActive(completion)}
        })
    }
    @objc private func appWillResignActiveMainThread(notification: Notification) {
        submitToDispatchGroup(block: { completion in
            self.mmContext.queue.async {self.appWillResignActive(completion)}
        })
    }
    @objc private func appWillTerminateMainThread(notification: Notification) {
        submitToDispatchGroup(block: { completion in
            self.mmContext.queue.async {self.appWillTerminate(completion)}
        })
    }
    @objc private func appDidEnterBackgroundMainThread(notification: Notification) {
        submitToDispatchGroup(block: { completion in
            self.mmContext.queue.async {self.appDidEnterBackground(completion)}
        })
    }
    @objc private func geoServiceDidStartMainThread(notification: Notification) {
        submitToDispatchGroup(block: { completion in
            self.mmContext.queue.async {self.geoServiceDidStart(completion)}
        })
    }
    @objc private func handleAppDidFinishLaunchingNotification(notification: Notification) {
        guard notification.userInfo?[UIApplication.LaunchOptionsKey.remoteNotification] == nil else {
            // we don't want to work on launching when push received.
            return
        }
        submitToDispatchGroup(block: { completion in
            self.mmContext.queue.async {self.appDidFinishLaunching(notification, completion: completion)}
        })
    }
    
    open func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
        completion()
    }
    
    open func handlesInAppNotification(forMessage message: MM_MTMessage?) -> Bool { return false }
    open func showBannerNotificationIfNeeded(forMessage message: MM_MTMessage?, showBannerWithOptions: @escaping (UNNotificationPresentationOptions) -> Void) {
        showBannerWithOptions([])
    }
    
    private func stopObserving() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupAppStateObserving() {
        if !isTestingProcessRunning {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appWillResignActiveMainThread(notification:)),
                name: UIApplication.willResignActiveNotification, object: nil)
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidBecomeActiveMainThread(notification:)),
                name: UIApplication.didBecomeActiveNotification, object: nil)
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appWillTerminateMainThread(notification:)),
                name: UIApplication.willTerminateNotification, object: nil)
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidEnterBackgroundMainThread(notification:)),
                name: UIApplication.didEnterBackgroundNotification, object: nil)
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appWillEnterForegroundMainThread(notification:)),
                name: UIApplication.willEnterForegroundNotification, object: nil)
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleAppDidFinishLaunchingNotification(notification:)),
                name: UIApplication.didFinishLaunchingNotification, object: nil)
        }
    }
    
    private func setupSDKObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(geoServiceDidStartMainThread(notification:)),
            name: NSNotification.Name(rawValue: MMNotificationGeoServiceDidStart), object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mobileMessagingWillStop(notification:)),
            name: NSNotification.Name(rawValue: "mobileMessagingWillStop"), object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mobileMessagingWillStart(notification:)),
            name: NSNotification.Name(rawValue: "mobileMessagingWillStart"), object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mobileMessagingDidStart(notification:)),
            name: NSNotification.Name(rawValue: "mobileMessagingDidStart"), object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pushRegistrationStatusDidChange(notification:)),
            name: NSNotification.Name(rawValue: "pushRegistrationStatusDidChange"), object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(depersonalizationStatusDidChange(notification:)),
            name: NSNotification.Name(rawValue: "depersonalizationStatusDidChange"), object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(baseUrlDidChange(notification:)),
            name: NSNotification.Name(rawValue: "baseUrlDidChange"), object: nil)
    }
    
    private func stopAppStateObserving() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didFinishLaunchingNotification, object: nil)
    }
}
