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
	
	///You can define your own custom appearance for chat view by accessing a chat settings object.
    public let settings: ChatSettings = ChatSettings.sharedInstance
	
	///Method for clean up WKWebView's cache. Mobile Messaging SDK will call it in case of user depersonalization. You can call it additionaly in case your user logouts from In-app Chat.
	///`completion` will be called when cache clean up is finished.
	public func cleanCache(completion: (() -> Void)? = nil) {
		MMLogDebug("[InAppChat] cache cleanup")
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
			self.delegate?.inAppChatIsEnabled(isEnabled)
		}
	}
	
	private let getWidgetQueue = MMOperationQueue.newSerialQueue
	private var chatWidget: ChatWidget?
	private var isEnabled: Bool = false
	var isChatScreenVisible: Bool = false
	
	override var systemData: [String: AnyHashable]? {
		return ["inappchat": true]
	}
	var webViewDelegate: ChatWebViewDelegate? {
		didSet {
			update(withChatWidget: chatWidget)
		}
	}
	
	static var sharedInstance: InAppChatService?

	init(mmContext: MobileMessaging) {
		super.init(mmContext: mmContext, id: "com.mobile-messaging.subservice.inappchat")
	}

	override func mobileMessagingDidStop(_ mmContext: MobileMessaging) {
		self.isEnabled = false
		chatWidget = nil
		cleanCache()
		stop {_ in }
		InAppChatService.sharedInstance = nil
	}
	
	override func mobileMessagingDidStart(_ mmContext: MobileMessaging) {
		start { _ in }
		getChatWidget()
	}
	
	override func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
		cleanCache(completion: completion)
	}
	
	override func handlesInAppNotification(forMessage message: MTMessage?) -> Bool {
		MMLogDebug("[InAppChat] handlesInAppNotification: \(message?.isChatMessage ?? false)")
		return message?.isChatMessage ?? false
	}
	
	override func showBannerNotificationIfNeeded(forMessage message: MTMessage?, showBannerWithOptions: @escaping (UNNotificationPresentationOptions) -> Void) {
		MMLogDebug("[InAppChat] showBannerNotificationIfNeeded isChatMessage: \(message?.isChatMessage ?? false), isExpired: \(message?.isExpired ?? false),  isChatScreenVisible: \(isChatScreenVisible), enabled: \(InteractiveMessageAlertSettings.enabled)")
		guard let message = message, !message.isExpired, InteractiveMessageAlertSettings.enabled, !isChatScreenVisible else {
				showBannerWithOptions([])
				return
		}
		
		showBannerWithOptions(UNNotificationPresentationOptions.make(with:  MobileMessaging.sharedInstance?.userNotificationType ?? []))
	}
	
	private func getChatWidget() {
		getWidgetQueue.addOperation(GetChatWidgetOperation(mmContext: mmContext) { (error, widget)  in
			self.chatWidget = widget
			self.isEnabled = (error == nil)
			self.delegate?.inAppChatIsEnabled(self.isEnabled)
			self.update(withChatWidget: self.chatWidget)
		})
	}
	
	private func update(withChatWidget: ChatWidget?) {
		guard let chatWidget = chatWidget else {
			return
		}
		
		let update = { [weak self] (widget: ChatWidget) in
			self?.webViewDelegate?.loadWidget(widget)
			if let title = widget.title {
				self?.settings.title = title
			}
			if let primaryColor = widget.primaryColor {
				self?.settings.sendButtonTintColor = UIColor(hexString: primaryColor)
			}
		}
		if let pushRegEnabled = MobileMessaging.currentInstallation?.isPushRegistrationEnabled,
			pushRegEnabled {
			update(chatWidget)
		} else {
			NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: MMNotificationInstallationSynced), object: nil, queue: nil) { (notification) in
				update(chatWidget)
				NotificationCenter.default.removeObserver(self)
			}
		}
	}
}

public protocol InAppChatDelegate {
	///In-app Chat can be disabled or not bind to the application on the Infobip portal. In these cases `enabled` will be `false`.
	///You can use this, for example, to show or not chat button to the user.
	func inAppChatIsEnabled(_ enabled: Bool)
}
