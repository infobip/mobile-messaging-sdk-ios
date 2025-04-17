//
//  ChatService.swift
//  MobileMessaging
//
//  Created by okoroleva on 26.04.2020.
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
    private var chatWidget: ChatWidget?
    private var isConfigurationSynced: Bool = false
    private var callsEnabled: Bool?
    public var jwt: String?
    public var domain: String? // Do not edit unless you have an agreement with Infobip to define the auth domain. 
    internal var ChatRegistrationId: String? {
        didSet {
            if let newRegId = ChatRegistrationId {
                UserEventsManager.postChatRegistrationReceived(newRegId)
            }
        }
    }
    var isChatScreenVisible: Bool = false
    
    public lazy var api: MMInAppChatWidgetAPIProtocol = MMInAppChatWidgetAPI()
    
	init(mmContext: MobileMessaging) {
        self.q = DispatchQueue(label: "chat-service", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        self.getWidgetQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q)
        self.getChatRegistrationQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q)
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
	public var delegate: MMInAppChatDelegate? {
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
        subscriber?.didReceiveError(chatErrors)
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
    
    private func syncWithServerIfNeeded(_ completion: @escaping (NSError?) -> Void) {
        if !isConfigurationSynced {
            chatErrors.rawDescription = nil
            chatErrors.remove(.configurationSyncError)
            chatErrors.remove(.jsError)
            getChatWidget(completion)
            obtainChatRegistrations()
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
                _self.chatErrors.rawDescription = error?.localizedDescription
                _self.chatErrors.insert(.configurationSyncError)
            }
            _self.update(withChatWidget: _self.chatWidget)
            completion?(error)
		})
	}
	
    private var installationReceivers: [WidgetSubscriber] = []
    private func update(withChatWidget: ChatWidget?, for subscriber: WidgetSubscriber? = nil) {
		guard let chatWidget = chatWidget else {
			return
		}
		
        if MobileMessaging.currentInstallation?.pushRegistrationId != nil {
            subscriber?.didLoadWidget(chatWidget)
            obtainChatRegistrations()
		} else {
            if let loader = subscriber {
                installationReceivers.append(loader)
            }
            NotificationCenter.default.addObserver(self, selector: #selector(notificationInstallationSyncedHandler), name: NSNotification.Name(rawValue: MMNotificationInstallationSynced), object: nil)
		}
        MMChatSettings.sharedInstance.update(withChatWidget: chatWidget)
	}


    @objc
    private func personalizedEventReceived() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            // We give time to People to reflect the change
            self?.obtainChatRegistrations()
        }
    }

    internal func obtainChatRegistrations() {
        // Chat registrarions are only needed for "calls enabled" widgest. Skip otherwise.
        guard let widgetId = chatWidget?.widgetId, (chatWidget?.callsEnabled ?? true) else { return }
        getChatRegistrationQueue.addOperation(
            GetChatRegistrationsOperation(mmContext: mmContext) { [weak self] (error, ChatRegistrations) in
                if let error = error {
                    self?.logError("Error while requesting Chat registrations: \(error)")
                } else if let newRegistrationId = ChatRegistrations?[widgetId] {
                    DispatchQueue.main.async {
                        self?.ChatRegistrationId = newRegistrationId
                    }
                }
        })
    }

    // MARK: Notifications handling
    
    @objc func notificationInstallationSyncedHandler() {
        guard let chatWidget = chatWidget else {
            return
        }
        installationReceivers.forEach {
            $0.didLoadWidget(chatWidget)
        }
        installationReceivers.removeAll()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: MMNotificationInstallationSynced), object: nil)
    }
    
    @objc func notificationRegistrationUpdatedHandler() {
        self.syncWithServerIfNeeded { _ in}
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil)
    }
    
    // MARK: Error handling
    private var chatErrors: ChatErrors = .none {
        didSet {
            webViewDelegate?.didReceiveError(chatErrors)
        }
    }
    private let networkReachabilityManager = NetworkReachabilityManager();
    
   func handleJSError(_ error: String?) {
        chatErrors.rawDescription = error
        chatErrors.insert(.jsError)
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
                    _self.syncWithServer {_ in}
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
    
    /// Method for setting the chat language, both in the WKWebView's system messages and the inputs. We'll consider only the left side of a locale and try to recognise the language. If unsupported, English will be set instead. Language must be set before WKWebView is loaded or presented.
    @objc public func setLanguage(_ localeString: String) {
        let separator = localeString.contains("_") ? "_" : "-"
        let components = localeString.components(separatedBy: separator)
        MMLanguage.sessionLanguage = MMLanguage.mapLanguage(from: components.first ??
                                                         String(localeString.prefix(2)))
        MMChatSettings.sharedInstance.postAppearanceChangedNotification()
    }
    
    internal var contextualData: ContextualData?
    
    
    ///  Send contextual metadata and an InAppChatMultiThreadFlag flag
    ///
    /// - Parameter metadata: Contextual data in JSON format.
    /// - Parameter multiThreadStrategy: `ALL` metadata sent to all non-closed conversations for a widget. `ACTIVE` metadata sent to active only conversation for a widget.
    public func sendContextualData(
        _ metadata: String,
        multiThreadStrategy: MMChatMultiThreadStrategy = .ACTIVE
    ) {
        guard let webViewDelegate = webViewDelegate else {
            self.contextualData = ContextualData(metadata: metadata, multiThreadStrategy: multiThreadStrategy)
            return
        }
        
        webViewDelegate.sendContextualData(ContextualData(metadata: metadata, multiThreadStrategy: multiThreadStrategy))
    }

    public override func handleAnyMessage(
        _ message: MM_MTMessage,
        completion: @escaping (MessageHandlingResult) -> Void
    ) {
        // TODO: only for regular push this will proceed. For InApp, it shall be ignored (handled by button tap actios)
        // TODO: What about old In-App though?
        guard message.appliedAction?.isTapOnNotificationAlert ?? false,
              let keyword = message.openLiveChatKeyword else {
            completion(.noData)
            return
        }

        guard let widgetId = chatWidget?.widgetId else {
            logError("WidgetId not found. In-App action could not open LiveChat")
            completion(.noData)
            return
        }

        // FIXME: it should be api.createThread(keyword) once LC BE is ready, see https://jira.infobip.com/browse/CHAT-3336
        api.sendText(keyword) { [weak self] error in
            if let error = error {
                self?.logError("Failure when sending LiveChat message \(keyword) on widgetId \(widgetId): error \(error.localizedDescription)")
            }
            self?.displayLiveChat(for: message, completion: completion)
        }
    }

    private func displayLiveChat(
        for message: MM_MTMessage,
        attempt: Int = 0,
        completion: @escaping (MessageHandlingResult
    ) -> Void) {
        // If the 'openingLivechat' delegate method below is implemented, the chat won't be presented, as the event will be delegated to the parent app. This allows choosing where the chat is presented, how is presented (in a root navigation bar, as modal, SUI HostingVC, etc.), and what input composer will be used (allowing a total replacement). Otherwise, default chat view controller (as full size navigation child VC) will be pushed in the navigation of the top view controller, if found.
        guard MobileMessaging.messageHandlingDelegate?.inAppOpenLiveChatActionTapped == nil else {
            MobileMessaging.messageHandlingDelegate?.inAppOpenLiveChatActionTapped?(for: message)
            logDebug("In-App action to open LiveChat was delegated to app side.")
            completion(MessageHandlingResult.noData)
            return
        }

        guard let presenterVC = MobileMessaging.messageHandlingDelegate?.inAppPresentingViewController?(for: message)
                ?? MobileMessaging.application.visibleViewController,
                let navBarC = presenterVC.navigationController else {
            // We allow a few retries, in 1 second intervals, in case MobileMessaging.application.visibleViewController was not initialized on time
            guard attempt < 3 else {
                logError("Unable to present chat view controller after receiving action to open LiveChat: no navigation controller available")
                completion(.noData)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
               self.displayLiveChat(for: message, attempt: attempt + 1, completion: completion)
            }
            return
        }

        DispatchQueue.mmEnsureMain {
            let chatVC = MMChatViewController.makeChildNavigationViewController()
            navBarC.pushViewController(chatVC, animated: true)
            self.logDebug("Chat view controller was presented after open LiveChat action.")
            completion(.newData)
        }
    }
}

struct ContextualData {
    var metadata: String
    var multiThreadStrategy: MMChatMultiThreadStrategy
}

protocol WidgetSubscriber {
    func didLoadWidget(_ widget: ChatWidget)
    func didReceiveError(_ errors: ChatErrors)
}

protocol ChatWebViewDelegate: AnyObject, WidgetSubscriber {
    func didEnableControls(_ enabled: Bool)
    func didShowComposeBar(_ visible: Bool)
    func didOpenPreview(forAttachment attachment: ChatWebAttachment)
    func didChangeView(_ state: MMChatWebViewState)
    func sendContextualData(_ contextualData: ContextualData)
}

@objc public protocol MMInAppChatDelegate {
	///In-app Chat can be disabled or not bind to the application on the Infobip portal. In these cases `enabled` will be `false`.
	///You can use this, for example, to show or hide chat button for the user.
    @objc optional func inAppChatIsEnabled(_ enabled: Bool)
    
    ///Called whenever a new chat push message arrives, contains current unread message counter value
    @objc optional func didUpdateUnreadMessagesCounter(_ count: Int)

    ///Called whenever an attachment exceeds the max allowed size and cannot be uploaded. If undefined, a localised alert will be displayed instead
    @objc optional func attachmentSizeExceeded(_ maxSize: UInt)

    ///Called whenever a text exceeds the max allowed lenght and cannot be sent.
    @objc optional func textLengthExceeded(_ maxLength: UInt)

    ///Called for informing about what view the chat is presenting. This is useful if your widget supports multiple
    ///threads, in which case you may want to hide the keyboard if something else than the chat view is presented
    @objc optional func chatDidChange(to state: MMChatWebViewState)

    ///Called for informing about an exception received from the widget, either upon loading or after a request from client side.
    /// You can decide (by returning a MMChatExceptionDisplayMode value) if the default error banner is presented for the exception, or you prefer to display an error UI of your own
    @objc optional func didReceiveException(_ exception: MMChatException) -> MMChatExceptionDisplayMode
}

extension UserEventsManager {
    class func postInAppChatAvailabilityUpdatedEvent(_ inAppChatEnabled: Bool) {
        post(MMNotificationInAppChatAvailabilityUpdated, [MMNotificationKeyInAppChatEnabled: inAppChatEnabled])
    }
    
    class func postInAppChatUnreadMessagesCounterUpdatedEvent(_ counter: Int) {
        post(MMNotificationInAppChatUnreadMessagesCounterUpdated, [MMNotificationKeyInAppChatUnreadMessagesCounter: counter])
    }

    class func postInAppChatViewChangedEvent(_ viewState: String) {
        post(MMNotificationInAppChatViewChanged, [MMNotificationKeyInAppChatViewChanged: viewState])
    }

    class func postChatRegistrationReceived(_ registrationId: String) {
        post(MMNotificationChatRegistrationReceived,
             [MMNotificationKeyChatRegistrationReceived: registrationId])
    }
}

struct ChatErrors: OptionSet {
    let rawValue: Int
    init(rawValue: Int = 0) { self.rawValue = rawValue }
    static let none = ChatErrors([])
    static let jsError = ChatErrors(rawValue: 1 << 0)
    static let configurationSyncError = ChatErrors(rawValue: 1 << 1)
    static let noInternetConnectionError = ChatErrors(rawValue: 1 << 2)
    var rawDescription: String?
    var localizedDescription: String {
        let somethingWrong = MMLocalization.localizedString(forKey: "mm_something_went_wrong",
                                                            defaultString: "Something went wrong.")
        if self.contains(.noInternetConnectionError) {
            return MMLocalization.localizedString(forKey: "mm_no_internet_connection",
                                                               defaultString: "No Internet connection")
        } else if self.contains(.configurationSyncError) || self.contains(.jsError) {
            guard let remoteDescription = rawDescription else { return somethingWrong }
            if UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
                return "\(remoteDescription) - " + somethingWrong
            } else {
                return somethingWrong + " - \(remoteDescription)"
            }
        }
        return somethingWrong
    }
}

@objc
public enum MMChatExceptionDisplayMode: Int {
    case displayDefaultAlert,
         noDisplay
}

@objc
public class MMChatException: NSObject, Error {
    public var code: Int
    public var name: String?
    public var message: String?
    public var retryable: Bool

    init(code: Int, name: String?, message: String?, retryable: Bool) {
        self.code = code
        self.name = name
        self.message = message
        self.retryable = retryable
    }
}
