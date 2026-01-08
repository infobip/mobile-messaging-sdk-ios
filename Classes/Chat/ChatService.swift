// 
//  ChatService.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import WebKit
import UIKit

public extension MobileMessaging {

	/// You access the In-app Chat service APIs through this property.
    class var inAppChat: MMInAppChatService? {
		if MMInAppChatService.sharedInstance == nil {
			guard let defaultContext = MobileMessaging.sharedInstance else {
				return nil
			}
			MMInAppChatService.sharedInstance = MMInAppChatService(mmContext: defaultContext)
		}
		return MMInAppChatService.sharedInstance
	}

	/// Fabric method for Mobile Messaging session.
	/// Use this method to enable the In-app Chat service.
    func withInAppChat() -> MobileMessaging {
		if MMInAppChatService.sharedInstance == nil {
			if let defaultContext = MobileMessaging.sharedInstance
			{
				MMInAppChatService.sharedInstance = MMInAppChatService(mmContext: defaultContext)
			}
		}
		return self
	}
}

// MARK: MMInAppChat Service

public class MMInAppChatService: MobileMessagingService {
    private let q: DispatchQueue
    static var sharedInstance: MMInAppChatService?
    static let resourceBundle: Bundle = {
    #if SWIFT_PACKAGE
        return Bundle.module
    #else
        guard let resourceBundleURL = MobileMessaging.bundle.url(forResource: "MMInAppChat", withExtension: "bundle"),
              let bundle = Bundle(url: resourceBundleURL) else {
            //in case of Carthage usage, MobileMessaging bundle will be used
            return MobileMessaging.bundle
        }
        return bundle
    #endif
    }()
    
    private let chatMessageCounterService: ChatMessageCounterService
    private let getWidgetQueue, getChatRegistrationQueue: MMOperationQueue
    var chatWidget: ChatWidget? {
        didSet {
            notifyInstallationReceivers()
        }
    }
    private var isConfigurationSynced: Bool = false
    private var callsEnabled: Bool?
    var isUsingJWT = false
    var isUsingAPI = false
    @available(*, deprecated, message: "This variable is going to be deprecated in a future version. Please use MMInAppChatDelegate's method getJWT() instead")
    public var jwt: String?
    public var domain: String? // Do not edit unless you have an agreement with Infobip to define the auth domain. 
    internal var chatRegistrationId: String? {
        didSet {
            if let newRegId = chatRegistrationId {
                UserEventsManager.postChatRegistrationReceived(newRegId)
            }
        }
    }
    var isChatScreenVisible: Bool = false
    var contextualData: ContextualData?
    
    public lazy var api: MMInAppChatWidgetAPIProtocol = MMInAppChatWidgetAPI()
    
	init(mmContext: MobileMessaging) {
        self.q = DispatchQueue(label: "chat-service", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        self.getWidgetQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q, name: "getWidgetQueue")
        self.getChatRegistrationQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q, name: "getChatRegistrationQueue")
        self.chatMessageCounterService = ChatMessageCounterService(mmContext: mmContext)
		super.init(mmContext: mmContext, uniqueIdentifier: "InAppChatService")
        self.chatMessageCounterService.chatService = self
	}
    
	///Method for clean up WKWebView's cache. Mobile Messaging SDK will call it in case of user depersonalization. You can call it additionaly in case your user logouts from In-app Chat.
	///`completion` will be called when cache clean up is finished.
	public func cleanCache(completion: (() -> Void)? = nil) {
		logDebug("cache cleanup")
        
        //removing saved attachments
        do {
            try FileManager.default.removeItem(at: URL.chatAttachmentDestinationFolderUrl(createIfNotExist: false))
        } catch {
            logError("error while removing attachments folder: \(error)")
        }
        
		DispatchQueue.main.async {
            WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                                                    modifiedSince: Date.init(timeIntervalSince1970: 0)) { [weak self] in
                guard let _self = self else {
                    completion?()
                    return
                }
                _self.update(withChatWidget: _self.chatWidget)
                completion?()
            }
            self.contextualData = nil
        }
    }
	
	///In-app Chat delegate, can be set to receive additional chat info.
	weak public var delegate: MMInAppChatDelegate? {
		didSet {
            DispatchQueue.main.async { [unowned self] in
                self.delegate?.inAppChatIsEnabled?(self.isConfigurationSynced)
            }
		}
	}
    
    ///Resets current unread chat push message counter to zero. MM SDK automatically resets the counter when MMChatViewController appears on screen.
    public func resetMessageCounter() {
        chatMessageCounterService.resetCounter()
    }
    
    ///Returns current unread chat push message counter.
    public var getMessageCounter: Int {
        return chatMessageCounterService.getCounter()
    }
	
    public override var systemData: [String: AnyHashable]? {
		return ["inappchat": true]
	}

    weak var webViewDelegate: ChatWebViewDelegate? {
		didSet {
            update(for: webViewDelegate)
        }
	}
    
    public var onRawMessageReceived: ((Any) -> Void)?

    public override func suspend() {
        NotificationCenter.default.removeObserver(self)
        getWidgetQueue.cancelAllOperations()
        getChatRegistrationQueue.cancelAllOperations()
        isConfigurationSynced = false
        notifyForChatAvailabilityChange()
        chatWidget = nil
        cleanCache()
        stopReachabilityListener()
        super.suspend()
    }
    
    public override func stopService(_ completion: @escaping (Bool) -> Void) {
        super.stopService(completion)
        MMInAppChatService.sharedInstance = nil
    }
	
    public override func mobileMessagingWillStart(_ completion: @escaping () -> Void) {
		start { _ in completion() }
	}
    
    public override func start(_ completion: @escaping (Bool) -> Void) {
        guard isRunning == false else {
            completion(isRunning)
            return
        }
        super.start(completion)
        startReachabilityListener()
        syncWithServer { _ in}
        // Personalisation changes LiveChat registration - we listen to it locally
        NotificationCenter.default.addObserver(self, selector: #selector(personalizedEventReceived), name: NSNotification.Name(rawValue: MMNotificationPersonalized), object: nil)
    }
	
    public override func depersonalizeService(_ mmContext: MobileMessaging, userInitiated: Bool, completion: @escaping () -> Void) {
        getWidgetQueue.cancelAllOperations()
        getChatRegistrationQueue.cancelAllOperations()
		cleanCache(completion: completion)
	}
	
    public override func handlesInAppNotification(forMessage message: MM_MTMessage?) -> Bool {
		logDebug("handlesInAppNotification: \(message?.isChatMessage ?? false)")
		return message?.isChatMessage ?? false
	}
	
    public override func showBannerNotificationIfNeeded(forMessage message: MM_MTMessage?, showBannerWithOptions: @escaping (UNNotificationPresentationOptions) -> Void) {
		logDebug("showBannerNotificationIfNeeded isChatMessage: \(message?.isChatMessage ?? false), isExpired: \(message?.isExpired ?? false),  isChatScreenVisible: \(isChatScreenVisible), enabled: \(MMInteractiveMessageAlertSettings.enabled)")
		guard let message = message, !message.isExpired, MMInteractiveMessageAlertSettings.enabled, !isChatScreenVisible else {
				showBannerWithOptions([])
				return
		}
		
		showBannerWithOptions(UNNotificationPresentationOptions.make(with:  MobileMessaging.sharedInstance?.userNotificationType ?? []))
	}
    
    public override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        syncWithServer({_ in completion() })
    }
    
    func update(for subscriber: WidgetSubscriber?) {
        subscriber?.didReceive(chatErrors)
        update(withChatWidget: chatWidget, for: subscriber)
    }

    func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
        if MobileMessaging.currentInstallation?.pushRegistrationId != nil {
            syncWithServerIfNeeded(completion)
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(notificationRegistrationUpdatedHandler), name: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil)
            completion(nil)
        }
    }
    
    func resetErrors() {
        chatErrors = MMChatRemoteError.none
    }
    
    private func syncWithServerIfNeeded(_ completion: @escaping (NSError?) -> Void) {
        if !isConfigurationSynced, !chatErrors.contains(.noInternetConnectionError) {
            resetErrors()
            getChatWidget(completion)
            obtainChatRegistrations()
        } else {
            completion(nil)
        }
    }
	
    private func getChatWidget(_ completion: ((NSError?) -> Void)? = nil) {
        guard isRunning else {
            completion?(nil)
            return
        }
        
		getWidgetQueue.addOperation(GetChatWidgetOperation(mmContext: mmContext) { [weak self]  (error, widget)  in
            
            guard let _self = self else {
                return
            }
            _self.chatWidget = widget
            _self.isConfigurationSynced = (error == nil)
            _self.notifyForChatAvailabilityChange()
            if !_self.isConfigurationSynced {
                var errors = _self.chatErrors // We first use a copy to overwrite the original (and call didSet) just once
                errors.insert(.configurationSyncError)
                errors.rawDescription = error?.localizedDescription
                _self.chatErrors = errors
            }
            _self.update(withChatWidget: _self.chatWidget)
            completion?(error)
		})
	}
	
    @MainActor private(set) var installationReceivers: [WidgetSubscriberWeak] = []
    
    func cleanEmptyReceiverWrappers() {
        Task { @MainActor in
            installationReceivers = installationReceivers.filter { $0.value != nil }
        }
    }
        
    private func update(withChatWidget: ChatWidget?, for subscriber: WidgetSubscriber? = nil) {
        guard let chatWidget = chatWidget else {
            // If widget is not ready, the subscriber is saved and it will be informed later
            if let loader = subscriber {
                Task { @MainActor in
                    installationReceivers.append(WidgetSubscriberWeak(loader))
                }
            }
            return
        }
        subscriber?.didLoad(chatWidget)
        obtainChatRegistrations()
        MMChatSettings.sharedInstance.update(withChatWidget: chatWidget)
	}


    @objc
    private func personalizedEventReceived() {
        if chatWidget == nil {
            // This could be the case where the operations were cancelled due to forceDepersonalization
            getChatWidget { _ in }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            // We give time to People to reflect the change
            self?.obtainChatRegistrations()
        }
    }

    internal func obtainChatRegistrations() {
        // Chat registrations are only needed for "calls enabled" widgets. Skip otherwise.
        guard let widgetId = chatWidget?.id, (chatWidget?.callsEnabled ?? true) else { return }
        getChatRegistrationQueue.addOperation(
            GetChatRegistrationsOperation(mmContext: mmContext) { [weak self] (error, ChatRegistrations) in
                if let error = error {
                    self?.logError("Error while requesting Chat registrations: \(error)")
                } else if let newRegistrationId = ChatRegistrations?[widgetId] {
                    DispatchQueue.main.async {
                        self?.chatRegistrationId = newRegistrationId
                    }
                }
        })
    }

    // MARK: Notifications handling
    
    func notifyInstallationReceivers() {
        guard let chatWidget = chatWidget else { return }
        Task { @MainActor in
            installationReceivers.forEach {
                $0.value?.didLoad(chatWidget)
            }
            installationReceivers.removeAll()
        }
    }
    
    @objc func notificationRegistrationUpdatedHandler() {
        self.syncWithServerIfNeeded { _ in}
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil)
    }
    
    // MARK: Error handling
    internal var chatErrors: MMChatRemoteError = .none {
        didSet {
            webViewDelegate?.didReceive(chatErrors)
        }
    }
    private let networkReachabilityManager = NetworkReachabilityManager();
    
   func handleJSError(_ error: ErrorJSMessage) {
       var errors = chatErrors
       errors.insert(.jsError)
       errors.rawDescription = error.message
       errors.additionalInfo = error.additionalInfo
       chatErrors = errors
    }
    
    private func startReachabilityListener() {
        networkReachabilityManager?.listener = { [weak self] status in
            guard let _self = self else {
                return
            }
            if status == .notReachable {
                _self.chatErrors.insert(.noInternetConnectionError)
            } else {
                if _self.chatErrors.contains(.noInternetConnectionError) {
                    _self.chatErrors.remove(.noInternetConnectionError)
                    _self.syncWithServer { [weak self] _ in
                        // When we reconnect, and JWT is used, we need to reload the widget with fresh JWT, as network reconnections trigger 'identify' method in widget
                        guard (self?.isUsingJWT ?? false) else { return }
                        self?.reloadChat()
                    }
                }
            }
        }
        networkReachabilityManager?.startListening()
    }
    
    private func stopReachabilityListener() {
        networkReachabilityManager?.stopListening()
    }
    
    private func notifyForChatAvailabilityChange() {
        DispatchQueue.main.async { [unowned self] in
            UserEventsManager.postInAppChatAvailabilityUpdatedEvent(self.isConfigurationSynced)
            self.delegate?.inAppChatIsEnabled?(self.isConfigurationSynced)
        }
    }
    
    public override func handleAnyMessage(
        _ message: MM_MTMessage,
        completion: @escaping (MessageHandlingResult) -> Void
    ) {
        guard let tapIdentifier = message.appliedAction?.identifier,
               (tapIdentifier == MMNotificationAction.DefaultActionId ||
               tapIdentifier == MMNotificationAction.PrimaryActionId),
               message.isOpenLiveChat else {
            completion(.noData)
            return
        }
        // Only livechat related actions should proceed opening livechat
        handleOpenLiveChatAction(message, attempt: 0, completion: completion)
    }
}
