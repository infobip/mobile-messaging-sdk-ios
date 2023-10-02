//
//  MMWebRTCService.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 14.10.2022.
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
		if MMWebRTCService.sharedInstance == nil {
			guard let defaultContext = MobileMessaging.sharedInstance else {
				return nil
			}
            MMWebRTCService.sharedInstance = MMWebRTCService(mmContext: defaultContext)
		}
		return MMWebRTCService.sharedInstance
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
        if MMWebRTCService.sharedInstance == nil {
            if let defaultContext = MobileMessaging.sharedInstance
            {
                MMWebRTCService.sharedInstance = MMWebRTCService(mmContext: defaultContext)
            }
        }
        MMWebRTCService.sharedInstance?.configurationId = configurationId
        MMWebRTCService.sharedInstance?.identityMode = mode
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

/// This service manages the In-app Chat.
public class MMWebRTCService: MobileMessagingService {
    internal let q: DispatchQueue
    static var sharedInstance: MMWebRTCService?
    public var notificationData: MMWebRTCNotificationData?
    internal var isRegistered = false
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
		super.init(mmContext: mmContext, uniqueIdentifier: "CallService")
	}

	///You can define your own custom appearance for chat view by accessing a chat settings object.
    public let settings: MMWebRTCSettings = MMWebRTCSettings.sharedInstance
	
	///In-app Chat delegate, can be set to receive additional chat info.
	public var delegate: MMWebRTCDelegate?
    
    public override var systemData: [String: AnyHashable]? {
		return ["webrtcui": true]
	}

    public override func suspend() {
        MMLogDebug("webrtcui service suspended")
        NotificationCenter.default.removeObserver(self)
        if isRegistered {
            disableCallPushCredentials()
        } // else is the flow stopService -> suspended, and we can skip disabling push
        super.suspend()
    }

    public override func stopService(_ completion: @escaping (Bool) -> Void) {
        MMLogDebug("mobileMessagingDidStop webrtcui service")
        // stopping the service with a call ongoing can freeze Apple's coretelephony framework
        guard !isPhoneOnCall else {
            completion(false)
            return
        }
        disableCallPushCredentials() { [weak self] result in
            guard let self else { return }
            self.suspend()
            self.isRunning = false // isRunning indicates if the service is operational
            completion(self.isRegistered) // isRegistered refers to RTC side, if calls can be received
            // The service may successfully stop running locally, but completion could return failure. Reason is, we want
            // to stop functioning as much as we can, while letting know there was something online unexpected
            NotificationCenter.default.removeObserver(self)
            // Do not call super.stopService due to the completion handling explained above
        }
    }

    public override func mobileMessagingWillStart(_ completion: @escaping () -> Void) {
        start { _ in completion() }
	}
    
    public override func start(_ completion: @escaping (Bool) -> Void) {
        guard isRunning == false else {
            completion(isRunning)
            return
        }
        handleIdentityMode()
        syncWithServer { _ in}
        createCallsPushRegistry()
        super.start(completion)
    }

    private func handleIdentityMode() {
        if case .inAppChat = identityMode {
           NotificationCenter.default.addObserver(
               self,
               selector: #selector(handleInAppChatRegistration(_ :)),
               name: NSNotification.Name(rawValue: MMNotificationChatRegistrationReceived),
               object: nil)
        } else {
           NotificationCenter.default.removeObserver(
               self,
               name: NSNotification.Name(rawValue: MMNotificationChatRegistrationReceived),
               object: nil)
        }
    }

    public override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        syncWithServer({_ in completion() })
    }

    func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
        NotificationCenter.default.addObserver(self, selector: #selector(notificationRegistrationUpdatedHandler), name: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil)
        completion(nil)
    }
	
    /*
     Notifications handling
     */

    @objc
    func handleInAppChatRegistration(_ notification: Notification) {
        guard case .inAppChat = identityMode,
              let registrationId = notification.userInfo?[MMNotificationKeyChatRegistrationReceived] as? String,
              inAppChatRegistrationId != registrationId else { return }
        inAppChatRegistrationId = registrationId
        stopService({ [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // We let RTC to refresh the device token
                self?.start({ _ in })
            }
        })
    }

    @objc func notificationRegistrationUpdatedHandler() {
        if let pushCredentials = notificationData?.pushPKCredentials {
            useCallPushCredentials(pushCredentials)
        }
    }
   
    func isCallKitSupported() -> Bool {
        // WebRTC is not allowed in China. Offering it risks an Apple Store rejection.
        // IMPORTANT: You need to add, in your app release notes in AppStoreConnect, a text similar to:
        // "In this version and onwards, we do not use CallKit features for users in China. We detect the user's region using NSLocale".
        guard let regionCode =  NSLocale.current.regionCode else { return false }
        return !(regionCode.contains("CN") || regionCode.contains("CHN"))
    }
}
#endif
