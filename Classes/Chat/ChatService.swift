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
	public class var inAppChat: InAppChatService? {
		if InAppChatService.sharedInstance == nil {
			guard let defaultContext = MobileMessaging.sharedInstance else {
				return nil
			}
			InAppChatService.sharedInstance = InAppChatService(mmContext: defaultContext)
		}
		return InAppChatService.sharedInstance
	}

	/// Fabric method for Mobile Messaging session.
	/// Use this method to enable the In-app Chat service.
	public func withInAppChat() -> MobileMessaging {
		if InAppChatService.sharedInstance == nil {
			if let defaultContext = MobileMessaging.sharedInstance
			{
				InAppChatService.sharedInstance = InAppChatService(mmContext: defaultContext)
			}
		}
		return self
	}
}

/// This service manages the In-app Chat.
public class InAppChatService: MobileMessagingService {
	init(mmContext: MobileMessaging) {
		super.init(mmContext: mmContext, uniqueIdentifier: "InAppChatService")
	}
	///You can define your own custom appearance for chat view by accessing a chat settings object.
    public let settings: ChatSettings = ChatSettings.sharedInstance
	
	///Method for clean up WKWebView's cache. Mobile Messaging SDK will call it in case of user depersonalization. You can call it additionaly in case your user logouts from In-app Chat.
	///`completion` will be called when cache clean up is finished.
	public func cleanCache(completion: (() -> Void)? = nil) {
		logDebug("cache cleanup")
		DispatchQueue.main.async {
			WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
													modifiedSince: Date.init(timeIntervalSince1970: 0)) {
														self.update(withChatWidget: self.chatWidget)
														completion?()
			}
		}
	}
	
	///In-app Chat delegate, can be set to receive additional chat info.
	public var delegate: InAppChatDelegate? {
		didSet {
			self.delegate?.inAppChatIsEnabled(isConfigurationSynced)
		}
	}
	
	private let getWidgetQueue = MMOperationQueue.newSerialQueue
	private var chatWidget: ChatWidget?
    private var isConfigurationSynced: Bool = false {
        didSet {
            UserEventsManager.postInAppChatAvailabilityUpdatedEvent(isConfigurationSynced)
            delegate?.inAppChatIsEnabled(isConfigurationSynced)
        }
    }
    
	var isChatScreenVisible: Bool = false
	
	override var systemData: [String: AnyHashable]? {
		return ["inappchat": true]
	}
	var webViewDelegate: ChatWebViewDelegate? {
		didSet {
            webViewDelegate?.handleChatErrors(chatErrors)
			update(withChatWidget: chatWidget)
		}
	}
	
	static var sharedInstance: InAppChatService?

	override func mobileMessagingDidStop(_ mmContext: MobileMessaging) {
        getWidgetQueue.cancelAllOperations()
		self.isConfigurationSynced = false
		chatWidget = nil
		cleanCache()
		stop {_ in }
        stopReachabilityListener()
		InAppChatService.sharedInstance = nil
	}
	
	override func mobileMessagingDidStart(_ mmContext: MobileMessaging) {
		start { _ in }
        startReachabilityListener()
        syncWithServer { _ in}
	}
	
	override func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
        getWidgetQueue.cancelAllOperations()
		cleanCache(completion: completion)
	}
	
	override func handlesInAppNotification(forMessage message: MTMessage?) -> Bool {
		logDebug("handlesInAppNotification: \(message?.isChatMessage ?? false)")
		return message?.isChatMessage ?? false
	}
	
	override func showBannerNotificationIfNeeded(forMessage message: MTMessage?, showBannerWithOptions: @escaping (UNNotificationPresentationOptions) -> Void) {
		logDebug("showBannerNotificationIfNeeded isChatMessage: \(message?.isChatMessage ?? false), isExpired: \(message?.isExpired ?? false),  isChatScreenVisible: \(isChatScreenVisible), enabled: \(InteractiveMessageAlertSettings.enabled)")
		guard let message = message, !message.isExpired, InteractiveMessageAlertSettings.enabled, !isChatScreenVisible else {
				showBannerWithOptions([])
				return
		}
		
		showBannerWithOptions(UNNotificationPresentationOptions.make(with:  MobileMessaging.sharedInstance?.userNotificationType ?? []))
	}
    
    override func appWillEnterForeground(_ n: Notification) {
        syncWithServer({_ in})
    }

    override func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
        if !isConfigurationSynced {
            chatErrors.remove(.configurationSyncError)
            chatErrors.remove(.jsError)
            getChatWidget(completion)
        }
    }
	
    private func getChatWidget(_ completion: ((NSError?) -> Void)? = nil) {
		getWidgetQueue.addOperation(GetChatWidgetOperation(mmContext: mmContext) { (error, widget)  in
			self.chatWidget = widget
            self.isConfigurationSynced = (error == nil)
            self.handleConfigurationSyncError(error)
			self.update(withChatWidget: self.chatWidget)
            completion?(error)
		})
	}
	
	private func update(withChatWidget: ChatWidget?) {
		guard let chatWidget = chatWidget else {
			return
		}
		
        if MobileMessaging.currentInstallation?.pushRegistrationId != nil {
            webViewDelegate?.loadWidget(chatWidget)
		} else {
			NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: MMNotificationInstallationSynced), object: nil, queue: nil) { (notification) in
                self.webViewDelegate?.loadWidget(chatWidget)
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
                webViewDelegate?.handleChatErrors(chatErrors)
            }
        }
    private let networkReachabilityManager = NetworkReachabilityManager();
    
    private func handleConfigurationSyncError(_ error: NSError?) {
        if !isConfigurationSynced {
            chatErrors.insert(.configurationSyncError)
        }
    }
    
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
}

public protocol InAppChatDelegate {
	///In-app Chat can be disabled or not bind to the application on the Infobip portal. In these cases `enabled` will be `false`.
	///You can use this, for example, to show or not chat button to the user.
	func inAppChatIsEnabled(_ enabled: Bool)
}

extension UserEventsManager {
    class func postInAppChatAvailabilityUpdatedEvent(_ inAppChatEnabled: Bool) {
        post(MMNotificationInAppChatAvailabilityUpdated, [MMNotificationKeyInAppChatEnabled: inAppChatEnabled])
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
