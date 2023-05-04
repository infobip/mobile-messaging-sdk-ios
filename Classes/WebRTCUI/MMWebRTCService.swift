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

	/// Use this method to enable the WebRTCUIservice.
    public func withCalls(_ applicationId: String) -> MobileMessaging {
		if MMWebRTCService.sharedInstance == nil {
			if let defaultContext = MobileMessaging.sharedInstance
			{
                MMWebRTCService.sharedInstance = MMWebRTCService(mmContext: defaultContext)
			}
		}
        MMWebRTCService.sharedInstance?.applicationId = applicationId
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
    public var applicationId: String? // webrtc application id to use for calls

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
    
	override var systemData: [String: AnyHashable]? {
		return ["webrtcui": true]
	}

    override func suspend() {
        MMLogDebug("webrtcui service suspended")
        NotificationCenter.default.removeObserver(self)
        disableCallPushCredentials()
        super.suspend()
    }

    public override func stopService(_ completion: @escaping (Bool) -> Void) {
        MMLogDebug("mobileMessagingDidStop webrtcui service")
        // stopping the service with a call ongoing can freeze Apple's coretelephony framework
        guard !isPhoneOnCall else { return }
        NotificationCenter.default.removeObserver(self)
        disableCallPushCredentials()
        super.stopService(completion)
    }

	override func mobileMessagingWillStart(_ completion: @escaping () -> Void) {
        start { _ in completion() }
	}
    
    public override func start(_ completion: @escaping (Bool) -> Void) {
        guard isRunning == false else {
            completion(isRunning)
            return
        }
        syncWithServer { _ in}
        createCallsPushRegistry()
        super.start(completion)
    }

    override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        syncWithServer({_ in completion() })
    }

    func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
        NotificationCenter.default.addObserver(self, selector: #selector(notificationRegistrationUpdatedHandler), name: NSNotification.Name(rawValue: MMNotificationRegistrationUpdated), object: nil)
        completion(nil)
    }
	
    /*
     Notifications handling
     */
    
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
