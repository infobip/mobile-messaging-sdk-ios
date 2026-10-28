// 
//  MMWebRTCService.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import WebKit
import CallKit
import PushKit
import AVFoundation
#if WEBRTCUI_ENABLED
import InfobipRTC

public enum MMWebRTCIdentityMode {
    case `default`,
        custom(String),
        inAppChat
}

extension MobileMessaging {
	/// You access the WebRTCUI service APIs through this property.
	public class var webRTCService: MMWebRTCService? {
		return MMWebRTCService.sharedInstanceLock.withLock {
			guard let context = MobileMessaging.sharedInstance else { return nil }
			if let service = MMWebRTCService.sharedInstance, service.mmContext === context {
				return service
			}
			let service = MMWebRTCService(mmContext: context)
			MMWebRTCService.sharedInstance = service
			return service
		}
	}

    /// Use this method to enable and combine WebRTCUI with InAppChat. As result, your chat user will be able to receive calls from Infobip Conversations.
    /// This method will not allow other use cases - use the method withCalls below for a more custom setup. Keep in mind that you need to set InAppChat in
    /// order to have InAppChatCalls. Guide here: https://github.com/infobip/mobile-messaging-sdk-ios/wiki/In%E2%80%90app-chat
    /// - parameter configurationId: value of the mobile RTC configuration you can create and manage with this API: https://www.infobip.com/docs/api/channels/webrtc-calls/webrtc/save-push-configuration
    public func withInAppChatCalls(configurationId: String) -> MobileMessaging {
        return withCalls(configurationId: configurationId, mode: .inAppChat)
    }

    /// Use this method to enable WebRTCUI and define your use case, depending on the identity you define for the user.
    /// - parameter configurationId: value of the mobile RTC configuration you can create and manage with this API: https://www.infobip.com/docs/api/channels/webrtc-calls/webrtc/save-push-configuration
    /// - parameter mode: Value to define how the user identity will be handled when registering your device for calls:
    /// The "default" mode will handle identity for you, using the push registration Id of your device.
    /// The "custom" mode allows you to define the WebRTC identity. This is only recommended if you understand how Infobip RTC works.
    /// "inAppChat" mode is to be used when you want receive agents calls from Infobip Conversations. This mode is equivalent to the method: withInAppChatCalls above
    public func withCalls(configurationId: String, mode: MMWebRTCIdentityMode = .default) -> MobileMessaging {
        let service = MobileMessaging.webRTCService
        service?.configurationId = configurationId
        service?.identityMode = mode
        return self
    }

}

@objc public enum MMWebRTCRegistrationCode: Int {
    case success = 0, // all ready to receive and trigger calls
         callsNotSupportedError, // China region detected in the device settings. This is not allowed by Apple
         gettingTokenError, // WebRTC Token failed. You can restart the call registration and retry
         registeringForCallsError // Server gave an error. You can restart the call registration and retry
}

@objc public protocol MMWebRTCDelegate {
    ///Called when the call has been accepted (from the OS popup/view) and we are ready to handle the control of the call to ourselves
    func inboundCallEstablished(_ call: ApplicationCall, event: CallEstablishedEvent)
    func inboundWebRTCCallEstablished(_ call: WebrtcCall, event: CallEstablishedEvent)
    func callRegistrationEnded(with statusCode: MMWebRTCRegistrationCode, and error: Error?)
    func callUnregistrationEnded(with statusCode: MMWebRTCRegistrationCode, and error: Error?)
}

/// Tracks RTC enabling attempts. Disable requests and chat identity refresh can overlap these phases (they are async events to registration).
enum MMCallRegistrationPhase {
    case idle,
         obtainingToken, // RTC tokens are used for remote registering and unregistering for calls
         enabling(isRetrying: Bool), // a failed first attempt is retried once
         waitingToRetry // there could be an apple's pushkit invalidation, or service interruption, that queues a retry

    var isRegistering: Bool {
        if case .idle = self { return false }
        return true
    }
}

private enum MMWebRTCServiceStopContext: Equatable {
    case chatIdentityRefresh, sdkShutdown
}

private enum MMWebRTCServiceStopPhase {
    case waitingForCallEnd
    case disabling(MMWebRTCServiceStopContext)
    case retryScheduled

    var isShuttingDown: Bool {
        switch self {
        case .waitingForCallEnd, .disabling(.sdkShutdown), .retryScheduled: return true
        case .disabling(.chatIdentityRefresh): return false
        }
    }
}

final class MMCallPushDisablingRequest {
    /// Disabling is tricky due to latency and, being a public method, could affect the internal state of the service when operations are ongoing
    let id = UUID()
    var completions: [(Bool) -> Void] = []
    var notifyDelegate = false
    var retryAfterCompletion = false
    var isDisabling = false
    var enableWaitTimeoutWorkItem: DispatchWorkItem?
    var tokenTimeoutWorkItem: DispatchWorkItem?
    var tokenResult: MMResult<MMWebRTCToken>?
    var tokenContext: MMWebRTCTokenRequestContext?
    var timedOutEnableToken: String?
}

/// This service manages the WebRTCUI functionality.
public class MMWebRTCService: MobileMessagingService {
    /// Longer than the HTTP request timeout, with room for callback delivery.
    static let callPushOperationTimeout: TimeInterval = 25.0
    internal let q: DispatchQueue
    internal let callsPushDelegateQueue: DispatchQueue
    static let sharedInstanceLock = NSLock()
    static var sharedInstance: MMWebRTCService?
    private let notificationDataLock = NSLock()
    private var storedNotificationData: MMWebRTCNotificationData?
    public var notificationData: MMWebRTCNotificationData? {
        get {
            notificationDataLock.lock()
            defer { notificationDataLock.unlock() }
            return storedNotificationData
        }
        set {
            notificationDataLock.lock()
            defer { notificationDataLock.unlock() }
            storedNotificationData = newValue
        }
    }

    internal func updateNotificationData(_ update: (inout MMWebRTCNotificationData?) -> Void) {
        notificationDataLock.withLock {
            update(&storedNotificationData)
        }
    }

    internal func takeActiveNotificationCall() -> ActiveCall? {
        var activeCall: ActiveCall?
        updateNotificationData { data in
            activeCall = data?.activeCall
            data?.activeCall = nil
        }
        return activeCall
    }
    internal var isRegistered = false // Registration state is confined to the main queue.
    internal var registrationPhase: MMCallRegistrationPhase = .idle
    internal var registrationGeneration: UInt64 = 0 // Used to reject superseded requests.
    internal var registrationTimeoutWorkItem: DispatchWorkItem?
    internal var enablingCallPushToken: String?
    internal var currentPushCredentials: PKPushCredentials?
    internal var registeredPushToken: Data? // The token last registered with RTC; chat identity may arrive later.
    internal var callPushRegistrationMayStillBeActive = false // A failed disable leaves the RTC registration state uncertain.
    internal var callsPushRegistry: PKPushRegistry? // Apple's registration, related to the 'device token' value used in RTC
    internal let retiredCallPushRegistries = NSHashTable<PKPushRegistry>.weakObjects()
    internal var pendingDisableCallPush: MMCallPushDisablingRequest? // A request to disable that needs to wait until the service can handle it - as it may have parallel operations ongoing
    private var pendingStopCompletions: [(Bool) -> Void] = [] // Kept until chat refresh finishes or SDK shutdown succeeds.
    private var stopPhase: MMWebRTCServiceStopPhase? // Nil when no stop is active; confined to the main queue.
    internal var isShuttingDown: Bool { stopPhase?.isShuttingDown ?? false }
    internal var shutdownTokenContext: MMWebRTCTokenRequestContext?
    internal var lastCallPushTokenContext: MMWebRTCTokenRequestContext?
    private static let failedStopRetryDelays: [TimeInterval] = [10, 30, 60]
    private static var servicesAwaitingDisable = Set<MMWebRTCService>() // Retained on the main queue during background retries.
    private var failedStopRetryCount = 0
    internal let callObserver = CXCallObserver()
    private var callEndObserverDelegate: MMCallEndObserverDelegate?
    internal var pendingInAppChatRegistrationId: String? // Future chat identity used to register the call with
    private var chatRegistrationRefreshInProgress = false // Marks an update in Livechat registrationId
    public var callAppIcon: UIImage?
    public var configurationId: String?
    internal var inAppChatRegistrationId: String?
    public var identityMode: MMWebRTCIdentityMode = .default
    public var identity: String? {
        switch identityMode {
        case .default:
            return MobileMessaging.currentInstallation?.pushRegistrationId
        case .custom(let string):
            return string
        case .inAppChat:
            return inAppChatRegistrationId
        }
    }

    static let resourceBundle: Bundle = {
    #if SWIFT_PACKAGE
        return Bundle.module
    #else
        guard let resourceBundleURL = MobileMessaging.bundle.url(forResource: "MMWebRTCUI", withExtension: "bundle"),
              let bundle = Bundle(url: resourceBundleURL) else {
            // in case of Carthage usage, MobileMessaging bundle will be used
            return MobileMessaging.bundle
        }
        return bundle
    #endif
    }()
        
	init(mmContext: MobileMessaging) {
        self.q = DispatchQueue(label: "webrtcui-service", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        self.callsPushDelegateQueue = DispatchQueue(label: "webrtcui-pushkit-delegate", qos: .userInitiated)
		super.init(mmContext: mmContext, uniqueIdentifier: "CallService")
	}

	///You can define your own custom appearance for chat view by accessing a chat settings object.
    public let settings: MMWebRTCSettings = MMWebRTCSettings.sharedInstance
	
	///WebRTCUI delegate, can be set to receive additional chat info.
	public weak var delegate: MMWebRTCDelegate?
    
    public override var systemData: [String: AnyHashable]? {
		return ["webrtcui": true]
	}

    /// SDK shutdown reaches suspend through stopService(); 'chat identity refresh' uses the same stop path.
    /// Direct suspension also requests RTC disable after any enable and its retry. But a direct caller is responsible for starting the service again.
    public override func suspend() {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self else { return }
            self.chatRegistrationRefreshInProgress = false
            self.suspendOnMain()
        }
    }

    private func suspendOnMain(disableCallPush: Bool = true) {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: MMNotificationChatRegistrationReceived), object: nil)
        switch stopPhase {
        case .some(.waitingForCallEnd): break // The SDK stop still needs this observer.
        default:
            stopObservingCallEnd()
        }
        /// The RTC request may already be running even though local registration is incomplete.
        if disableCallPush && !isShuttingDown && pendingDisableCallPush == nil && (isRegistered || registrationPhase.isRegistering) {
            requestCallPushDisabling(nil, notifyDelegate: true)
        }
        if let callsPushRegistry {
            retiredCallPushRegistries.add(callsPushRegistry)
            callsPushRegistry.delegate = nil
            callsPushRegistry.desiredPushTypes = []
        }
        callsPushRegistry = nil
        MMLogDebug("[WebRTCUI] webrtcui service suspended")
        super.suspend()
    }

    public override func stopService(_ completion: @escaping (Bool) -> Void) {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self else { completion(false); return }
            self.chatRegistrationRefreshInProgress = false
            if self.shutdownTokenContext == nil {
                self.shutdownTokenContext = self.pendingDisableCallPush?.tokenContext ??
                    self.lastCallPushTokenContext ??
                    MMWebRTCTokenRequestContext(mmContext: self.mmContext, identity: self.identity)
            }
            self.stopServiceOnMain(completion, context: .sdkShutdown)
        }
    }

    public override func didRemoveFromMobileMessaging() {
        NotificationCenter.default.removeObserver(self)
        MMWebRTCService.sharedInstanceLock.withLock {
            if MMWebRTCService.sharedInstance === self {
                MMWebRTCService.sharedInstance = nil
            }
        }
    }

    private func stopServiceOnMain(_ completion: @escaping (Bool) -> Void, context: MMWebRTCServiceStopContext) {
        if Self.servicesAwaitingDisable.contains(self) {
            // A prior SDK stop returned; new callers must not wait for its background retry.
            completion(false)
            return
        }
        pendingStopCompletions.append(completion)
        guard let stopPhase else {
            failedStopRetryCount = 0
            beginPendingStopOnMain(context: context)
            return
        }
        switch stopPhase {
        case .disabling:
            // SDK shutdown takes precedence when it joins a chat identity refresh.
            if case .sdkShutdown = context { self.stopPhase = .disabling(.sdkShutdown) }
            MMLogDebug("[WebRTCUI] mobileMessaging joined parallel request to stop webrtcui service")
        case .waitingForCallEnd, .retryScheduled:
            break
        }
    }

    private func beginPendingStopOnMain(context: MMWebRTCServiceStopContext) {
        // A shutdown retry can reach here after its stop completions have already returned.
        stopPhase = .disabling(context)
        if isPhoneOnCall {
            if case .sdkShutdown = context {
                // Disabling during any CallKit call can freeze CoreTelephony.
                stopPhase = .waitingForCallEnd
                observeCallEndIfNeeded()
                MMLogDebug("[WebRTCUI] waiting for active call before stopping webrtcui service")
            } else {
                completePendingStopOnMain(result: false)
            }
            return
        }
        // With no known registration or token context, there is no RTC operation to wait for.
        if !isRegistered, !callPushRegistrationMayStillBeActive,
           !registrationPhase.isRegistering,
           (shutdownTokenContext ?? MMWebRTCTokenRequestContext(mmContext: mmContext, identity: identity)) == nil {
            if configurationId != nil {
                MMLogWarn("[WebRTCUI] no call identity or token provider available during stop")
            }
            completePendingStopOnMain(result: true)
            return
        }
        // A running RTC enable must settle before disable is sent. Even when isRegistered is false,
        // a previous process or a failed enable may have left a remote registration to remove.
        let isBackgroundShutdownRetry = context == .sdkShutdown && Self.servicesAwaitingDisable.contains(self)
        requestCallPushDisabling({ [weak self] result in
            guard let self else { return }
            self.completePendingStopOnMain(result: result)
            /// Do not call super.stopService: its completion reports isRunning instead of the result of unregistering calls.
        }, notifyDelegate: !isBackgroundShutdownRetry)
        MMLogDebug("[WebRTCUI] mobileMessaging requested to stop webrtcui service")
    }

    private func completePendingStopOnMain(result: Bool) {
        guard case .some(.disabling(let context)) = stopPhase else { return }
        if result || context == .sdkShutdown {
            suspendOnMain(disableCallPush: false)
        }
        MMLogDebug("[WebRTCUI] stopped webrtcui service with result \(result)")
        if !result && context == .sdkShutdown {
            if failedStopRetryCount < Self.failedStopRetryDelays.count {
                let delay = Self.failedStopRetryDelays[failedStopRetryCount]
                failedStopRetryCount += 1
                stopPhase = .retryScheduled
                MMLogWarn("[WebRTCUI] call push disable failed; retrying after SDK shutdown in \(delay) seconds")
                // Core may release its subservice as soon as these completions run.
                Self.servicesAwaitingDisable.insert(self)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, case .some(.retryScheduled) = self.stopPhase else { return }
                    self.beginPendingStopOnMain(context: .sdkShutdown)
                }
            } else {
                MMLogError("[WebRTCUI] call push disable failed after \(failedStopRetryCount + 1) attempts; remote registration may remain active")
                stopPhase = nil
                shutdownTokenContext = nil
                Self.servicesAwaitingDisable.remove(self)
            }
            let completions = pendingStopCompletions
            pendingStopCompletions.removeAll()
            completions.forEach { $0(false) }
            return
        }
        stopPhase = nil
        if case .sdkShutdown = context {
            failedStopRetryCount = 0
            shutdownTokenContext = nil
            Self.servicesAwaitingDisable.remove(self)
        }
        let completions = pendingStopCompletions
        pendingStopCompletions.removeAll()
        completions.forEach { $0(result) }
    }

    public override func mobileMessagingWillStart(_ completion: @escaping () -> Void) {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self else { completion(); return }
            if self.pendingDisableCallPush != nil {
                self.requestCallPushDisabling({ [weak self] _ in
                    guard let self else { completion(); return }
                    self.start { _ in completion() }
                }, notifyDelegate: false)
            } else {
                self.start { _ in completion() }
            }
        }
	}
    
    /// Note: start() does not queue a restart. If it returns false (because a disable is in progress), wait for the earlier operation to finish, then call start() again.
    /// Use stopService when you need a result before restarting; suspend() starts an asynchronous unregistration without a completion.
    public override func start(_ completion: @escaping (Bool) -> Void) {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self else { completion(false); return }
            self.startOnMain(completion)
        }
    }

    private func startOnMain(_ completion: @escaping (Bool) -> Void) {
        guard !isShuttingDown else {
            completion(false)
            return
        }
        guard pendingDisableCallPush == nil else {
            completion(false)
            MMLogDebug("[WebRTCUI] mobileMessaging could not start webrtcui: a previous disabling is ongoing")
            return
        }
        /// Case where the last disabling failed, but chat identity remained - we retry a clean restart, keeping the chat identity as it may still be valid.
        // If disabling fails again, the caller receives false and may retry later.
        if !isRunning, pendingInAppChatRegistrationId != nil,
           (isRegistered || callPushRegistrationMayStillBeActive) {
            requestCallPushDisabling({ [weak self] disabled in
                guard let self, disabled else {
                    completion(false)
                    MMLogDebug("[WebRTCUI] mobileMessaging could not start webrtcui: call push disabling failed")
                    return
                }
                self.startOnMain(completion)
            }, notifyDelegate: true)
            return
        }
        /// Case where we succeeded in the previous case: we did disable calls successfully and are about to do a clean restart on previous identity
        if !isRunning, let pendingId = pendingInAppChatRegistrationId {
            inAppChatRegistrationId = pendingId
            pendingInAppChatRegistrationId = nil
            stopObservingCallEnd()
        } else if pendingInAppChatRegistrationId != nil { // A chat identity refresh is pending.
            processPendingChatRegistration()
        }
        /// Case where restarting is unnecessary, but we still will check if the registration is healthy
        guard isRunning == false else {
            retryCallRegistrationIfNeeded()
            completion(isRunning)
            MMLogDebug("[WebRTCUI] mobileMessaging was requested to start webrtcui while already running")
            return
        }
        handleIdentityMode() // Observe the chat identity when calls are linked to live chat.
        syncWithServer { _ in}
        createCallsPushRegistry() // PushKit supplies the VoIP token used for RTC registration.
        super.start { [weak self] started in
            /// Retry cached credentials while the new PushKit registry above obtains its token; a different token in didUpdate supersedes this registration attempt.
            if started {
                self?.retryCallRegistrationIfNeeded()
            }
            completion(started)
        }
    }

    private func handleIdentityMode() {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self = self else { return }
            /// inAppChat identity mode is used livechat dedicated calls
            if case .inAppChat = self.identityMode {
                /// First we create an observer: inAppChat will propagate the livechatRegistrationId when received (or updated)
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(handleInAppChatRegistration(_ :)),
                    name: NSNotification.Name(rawValue: MMNotificationChatRegistrationReceived),
                    object: nil)
                /// Refresh the chat identity after a suspension, when changes could not be observed.
                NotificationCenter.default.post(
                    name: NSNotification.Name(rawValue: MMNotificationChatRegistrationRequested),
                    object: self,
                    userInfo: nil)
            } else { // Other call modes do not need chat registration updates.
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSNotification.Name(rawValue: MMNotificationChatRegistrationReceived),
                    object: nil)
            }
        }
    }

    /// Healthy sync/refresh once app becomes active
    public override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        syncWithServer({ [weak self] _ in
            self?.processPendingChatRegistration()
            self?.retryCallRegistrationIfNeeded()
            completion()
        })
    }

    func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self else { completion(nil); return }
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(notificationRegistrationUpdatedHandler), name: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil)
            completion(nil)
        }
    }
	
    /*
     Notifications handling
     */

    @objc
    func handleInAppChatRegistration(_ notification: Notification) {
        DispatchQueue.mmEnsureMain { [weak self] in
            guard let self,
                  case .inAppChat = self.identityMode,
                  let registrationId = notification.userInfo?[MMNotificationKeyChatRegistrationReceived] as? String else {
                MMLogDebug("[WebRTCUI] chat registration did not happen yet - missing chat registrationId")
                return
            }
            if self.inAppChatRegistrationId == nil {
                self.inAppChatRegistrationId = registrationId
                self.retryCallRegistrationIfNeeded()
                MMLogDebug("[WebRTCUI] chat registration obtained")
                return
            }
            guard self.inAppChatRegistrationId != registrationId else {
                /// A refresh already in progress still needs to restart if the ID changes back.
                if self.chatRegistrationRefreshInProgress {
                    self.pendingInAppChatRegistrationId = registrationId
                } else if self.pendingInAppChatRegistrationId == registrationId {
                    self.pendingInAppChatRegistrationId = nil
                    self.stopObservingCallEnd()
                }
                self.retryCallRegistrationIfNeeded()
                MMLogDebug("[WebRTCUI] chat registration ID matches the active identity")
                return
            }
            /// MMWebRTCToken.obtain uses identity, so retain the old ID through RTC disable.
            self.pendingInAppChatRegistrationId = registrationId
            self.processPendingChatRegistration()
        }
    }

    private func observeCallEndIfNeeded() {
        // Wait for any active call, including calls outside this SDK, before stopping or refreshing the chat identity.
        if callEndObserverDelegate == nil {
            let delegate = MMCallEndObserverDelegate(service: self)
            callEndObserverDelegate = delegate
            callObserver.setDelegate(delegate, queue: .main)
        }
        /// Close the gap if the call ended between the initial check and observer installation.
        if !isPhoneOnCall {
            DispatchQueue.main.async {
                [weak self] in self?.handlePostCallEndActionsOnMain()
            }
        }
    }

    /// This method is called once a voice call ends, and there were actions (re-registrations, stops, etc) that were blocked by that call.
    fileprivate func handlePostCallEndActionsOnMain() {
        guard !isPhoneOnCall else { return }
        if case .some(.waitingForCallEnd) = stopPhase {
            beginPendingStopOnMain(context: .sdkShutdown)
        } else if stopPhase == nil, isRunning {
            processPendingChatRegistration()
        }
    }

    private func stopObservingCallEnd() {
        callObserver.setDelegate(nil, queue: nil)
        callEndObserverDelegate = nil
    }

    func processPendingChatRegistration() {
        guard stopPhase == nil else { return }
        guard MobileMessaging.sharedInstance === mmContext else {
            pendingInAppChatRegistrationId = nil
            stopObservingCallEnd()
            MMLogDebug("[WebRTCUI] chat pending registration failed - no mmContext")
            return
        }
        guard pendingInAppChatRegistrationId != nil,
              !chatRegistrationRefreshInProgress,
              pendingDisableCallPush == nil else {
            MMLogDebug("[WebRTCUI] chat registration refresh is not ready")
            return
        }
        if !isRunning {
            /// Directly suspended services adopt the new ID without restarting themselves.
            guard !isRegistered, !callPushRegistrationMayStillBeActive else {
                MMLogDebug("[WebRTCUI] chat registration tried without service running after being registered")
                return
            }
            inAppChatRegistrationId = pendingInAppChatRegistrationId
            pendingInAppChatRegistrationId = nil
            stopObservingCallEnd()
            MMLogDebug("[WebRTCUI] chat registration tried without service running")
            return
        }
        guard !isPhoneOnCall else {
            MMLogDebug("[WebRTCUI] chat registration tried during a phone call")
            observeCallEndIfNeeded()
            return
        }
        stopObservingCallEnd()
        chatRegistrationRefreshInProgress = true
        stopServiceOnMain({ [weak self] disabled in
            MMLogDebug("[WebRTCUI] stopped with result \(disabled) after receiving chat registration")
            guard let self else { return }
            guard disabled else {
                self.chatRegistrationRefreshInProgress = false
                if self.isPhoneOnCall {
                    self.observeCallEndIfNeeded()
                }
                /// Keep the pending ID for the next foreground, start, or call-end event.
                return
            }
            /// Give RTC time to release the old identity before starting the latest chat registration.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.completeChatRegistrationRefresh()
            }
        }, context: .chatIdentityRefresh)
    }

    private func completeChatRegistrationRefresh() {
        guard chatRegistrationRefreshInProgress else { return }
        guard pendingInAppChatRegistrationId != nil,
              MobileMessaging.sharedInstance === mmContext else {
            chatRegistrationRefreshInProgress = false
            return
        }
        if pendingDisableCallPush != nil {
            requestCallPushDisabling({ [weak self] disabled in
                guard let self else { return }
                if disabled {
                    self.completeChatRegistrationRefresh()
                } else {
                    self.chatRegistrationRefreshInProgress = false
                }
            }, notifyDelegate: false)
            return
        }
        chatRegistrationRefreshInProgress = false
        // startOnMain adopts the latest pending ID only after it can start.
        start { [weak self] started in
            guard let self else { return }
            if started {
                self.processPendingChatRegistration()
            } else {
                MMLogDebug("[WebRTCUI] chat registration restart failed; pending ID kept for a later retry")
            }
        }
    }

    @objc func notificationRegistrationUpdatedHandler() {
        retryCallRegistrationIfNeeded()
    }
   
    func isCallKitSupported() -> Bool {
        // WebRTC is not allowed in China. Offering it risks an Apple Store rejection.
        // IMPORTANT: You need to add, in your app release notes in AppStoreConnect, a text similar to:
        // "In this version and onwards, we do not use CallKit features for users in China. We detect the user's region using NSLocale".
        guard let regionCode =  NSLocale.current.regionCode else { return false }
        return !(regionCode.contains("CN") || regionCode.contains("CHN"))
    }
}

private final class MMCallEndObserverDelegate: NSObject, CXCallObserverDelegate {
    private weak var service: MMWebRTCService?

    init(service: MMWebRTCService) {
        self.service = service
    }

    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        DispatchQueue.mmEnsureMain { [weak self] in
            self?.service?.handlePostCallEndActionsOnMain()
        }
    }
}
#endif
