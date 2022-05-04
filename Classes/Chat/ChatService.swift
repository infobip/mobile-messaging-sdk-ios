//
//  ChatService.swift
//  MobileMessaging
//
//  Created by okoroleva on 26.04.2020.
//

import Foundation
import WebKit

extension MobileMessaging {

	/// You access the In-app Chat service APIs through this property.
	public class var inAppChat: MMInAppChatService? {
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
	public func withInAppChat() -> MobileMessaging {
		if MMInAppChatService.sharedInstance == nil {
			if let defaultContext = MobileMessaging.sharedInstance
			{
				MMInAppChatService.sharedInstance = MMInAppChatService(mmContext: defaultContext)
			}
		}
		return self
	}
}

/// This service manages the In-app Chat.
public class MMInAppChatService: MobileMessagingService {
    private let q: DispatchQueue
    static var sharedInstance: MMInAppChatService?
    private let chatMessageCounterService: ChatMessageCounterService
    private let getWidgetQueue: MMOperationQueue
    private var chatWidget: ChatWidget?
    private var isConfigurationSynced: Bool = false
    
    var isChatScreenVisible: Bool = false
    
	init(mmContext: MobileMessaging) {
        self.q = DispatchQueue(label: "chat-service", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        self.getWidgetQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q)
        self.chatMessageCounterService = ChatMessageCounterService(mmContext: mmContext)
		super.init(mmContext: mmContext, uniqueIdentifier: "InAppChatService")
        self.chatMessageCounterService.chatService = self
	}
    
	///You can define your own custom appearance for chat view by accessing a chat settings object.
    public let settings: MMChatSettings = MMChatSettings.sharedInstance
	
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
													modifiedSince: Date.init(timeIntervalSince1970: 0)) {
														self.update(withChatWidget: self.chatWidget)
														completion?()
			}
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
	
	override var systemData: [String: AnyHashable]? {
		return ["inappchat": true]
	}
	weak var webViewDelegate: ChatWebViewDelegate? {
		didSet {
            webViewDelegate?.didReceiveError(chatErrors)
			update(withChatWidget: chatWidget)
		}
	}

    override func suspend() {
        getWidgetQueue.cancelAllOperations()
        isConfigurationSynced = false
        notifyForChatAvailabilityChange()
        chatWidget = nil
        cleanCache()
        stopReachabilityListener()
        super.suspend()
    }
    
    override func mobileMessagingDidStop(_ completion: @escaping () -> Void) {
        MMInAppChatService.sharedInstance = nil
        completion()
    }
	
	override func mobileMessagingWillStart(_ completion: @escaping () -> Void) {
		start { _ in completion() }
	}
    
    override func start(_ completion: @escaping (Bool) -> Void) {
        guard isRunning == false else {
            completion(isRunning)
            return
        }
        super.start(completion)
        startReachabilityListener()
        syncWithServer { _ in}
    }
	
	override func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
        getWidgetQueue.cancelAllOperations()
		cleanCache(completion: completion)
	}
	
	override func handlesInAppNotification(forMessage message: MM_MTMessage?) -> Bool {
		logDebug("handlesInAppNotification: \(message?.isChatMessage ?? false)")
		return message?.isChatMessage ?? false
	}
	
	override func showBannerNotificationIfNeeded(forMessage message: MM_MTMessage?, showBannerWithOptions: @escaping (UNNotificationPresentationOptions) -> Void) {
		logDebug("showBannerNotificationIfNeeded isChatMessage: \(message?.isChatMessage ?? false), isExpired: \(message?.isExpired ?? false),  isChatScreenVisible: \(isChatScreenVisible), enabled: \(MMInteractiveMessageAlertSettings.enabled)")
		guard let message = message, !message.isExpired, MMInteractiveMessageAlertSettings.enabled, !isChatScreenVisible else {
				showBannerWithOptions([])
				return
		}
		
		showBannerWithOptions(UNNotificationPresentationOptions.make(with:  MobileMessaging.sharedInstance?.userNotificationType ?? []))
	}
    
    override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        syncWithServer({_ in completion() })
    }

    func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
        if MobileMessaging.currentInstallation?.pushRegistrationId != nil {
            syncWithServerIfNeeded(completion)
        } else {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil, queue: nil) { (notification) in
                self.syncWithServerIfNeeded(completion)
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
    
    private func syncWithServerIfNeeded(_ completion: @escaping (NSError?) -> Void) {
        if !isConfigurationSynced {
            chatErrors.remove(.configurationSyncError)
            chatErrors.remove(.jsError)
            getChatWidget(completion)
        }
    }
	
    private func getChatWidget(_ completion: ((NSError?) -> Void)? = nil) {
        guard isRunning else {
            completion?(nil)
            return
        }
		getWidgetQueue.addOperation(GetChatWidgetOperation(mmContext: mmContext) { (error, widget)  in
            self.chatWidget = widget
            self.isConfigurationSynced = (error == nil)
            self.notifyForChatAvailabilityChange()
            if !self.isConfigurationSynced {
                self.chatErrors.insert(.configurationSyncError)
            }
            self.update(withChatWidget: self.chatWidget)
            completion?(error)
		})
	}
	
	private func update(withChatWidget: ChatWidget?) {
		guard let chatWidget = chatWidget else {
			return
		}
		
        if MobileMessaging.currentInstallation?.pushRegistrationId != nil {
            webViewDelegate?.didLoadWidget(chatWidget)
		} else {
			NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: MMNotificationInstallationSynced), object: nil, queue: nil) { (notification) in
                self.webViewDelegate?.didLoadWidget(chatWidget)
				NotificationCenter.default.removeObserver(self)
			}
		}
        self.settings.update(withChatWidget: chatWidget)
	}
    
    /*
     Errors handling
     */
    
    private var chatErrors: ChatErrors = .none {
            didSet {
                webViewDelegate?.didReceiveError(chatErrors)
            }
        }
    private let networkReachabilityManager = NetworkReachabilityManager();
    
   func handleJSError(_ error: String?) {
        chatErrors.insert(.jsError)
    }
    
    private func startReachabilityListener() {
        networkReachabilityManager?.listener = { status in
            if status == .notReachable {
                self.chatErrors.insert(.noInternetConnectionError)
            } else {
                if self.chatErrors.contains(.noInternetConnectionError) {
                    self.chatErrors.remove(.noInternetConnectionError)
                    self.syncWithServer {_ in}
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
}

protocol ChatWebViewDelegate: AnyObject {
    func didLoadWidget(_ widget: ChatWidget)
    func didEnableControls(_ enabled: Bool)
    func didShowComposeBar(_ visible: Bool)
    func didReceiveError(_ errors: ChatErrors)
    func didOpenPreview(forAttachment attachment: ChatWebAttachment)
}

@objc public protocol MMInAppChatDelegate {
	///In-app Chat can be disabled or not bind to the application on the Infobip portal. In these cases `enabled` will be `false`.
	///You can use this, for example, to show or hide chat button for the user.
    @objc optional func inAppChatIsEnabled(_ enabled: Bool)
    
    ///Called whenever a new chat push message arrives, contains current unread message counter value
    @objc optional func didUpdateUnreadMessagesCounter(_ count: Int)
}

extension UserEventsManager {
    class func postInAppChatAvailabilityUpdatedEvent(_ inAppChatEnabled: Bool) {
        post(MMNotificationInAppChatAvailabilityUpdated, [MMNotificationKeyInAppChatEnabled: inAppChatEnabled])
    }
    
    class func postInAppChatUnreadMessagesCounterUpdatedEvent(_ counter: Int) {
        post(MMNotificationInAppChatUnreadMessagesCounterUpdated, [MMNotificationKeyInAppChatUnreadMessagesCounter: counter])
    }
}

struct ChatErrors: OptionSet {
    let rawValue: Int
    init(rawValue: Int = 0) { self.rawValue = rawValue }
    static let none = ChatErrors([])
    static let jsError = ChatErrors(rawValue: 1 << 0)
    static let configurationSyncError = ChatErrors(rawValue: 1 << 1)
    static let noInternetConnectionError = ChatErrors(rawValue: 1 << 2)
}
