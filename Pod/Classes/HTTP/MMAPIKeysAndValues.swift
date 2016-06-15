//
//  MMAPIKeysAndValues.swift
//  MobileMessaging
//
//  Created by okoroleva on 08.03.16.
//

import Foundation

struct MMAPIKeys {
	//MARK: API availability
	static let kFetchAPIEnabled = true
	static let kSeenAPIEnabled = true
	
    //MARK: registration
    static let kPlatformType = "platformType"
    static let kRegistrationId = "registrationId"
    static let kInternalRegistrationId = "deviceApplicationInstanceId"
    
    //MARK: delivery
    static let kMessageIDs = "messageIDs"
	
    //MARK: serviceErrors
    static let kRequestError = "requestError"
    static let kServiceException = "serviceException"
    static let kErrorText = "text"
    
    //MARK: APNs
    static let kPayloads = "payloads"
    static let kAps = "aps"
    static let kAlert = "alert"
    static let kTitle = "title"
    static let kBody = "body"
    static let kBadge = "badge"
    static let kSound = "sound"
    static let kData = "data"
	static let kContentAvailable = "content-available"
	
	//MARK: email
	static let kEmail = "email"
	
	//MARK: msisdn
	static let kMSISDN = "msisdn"
    
    //MARK: seenMessages
    static let kSeenMessages = "messages"
    static let kSeenTimestamp = "seenDate"
    
    //MARK: Common fields
    static let kMessageId = "messageId"
}

struct MMAPIValues {
	static let kProdBaseURLString = "https://oneapi.infobip.com"	
	static let kPlatformType = "APNS"
}

//MARK: Notification keys
	/**
	Key for entry in userInfo dictionary of `kRegistrationUpdated` notification.
	Contains an Internal Id string for the registered user.
	*/
	public let MMNotificationKeyRegistrationInternalId = "com.mobile-messaging.notification.registration-key"
	
	/**
	Key for entry in userInfo dictionary of `kRegistrationUpdated` notification.
	Contains a hex-encoded device token string received from APNS.
	*/
	public let MMNotificationKeyDeviceToken = "com.mobile-messaging.notification.device-token-key"
	
	/**
	Key for entry in userInfo dictionary of `kDeliveryReportSent` notification.
	Contains a an array of message ID strings.
	*/
	public let MMNotificationKeyDLRMessageIDs = "com.mobile-messaging.notification.dlr-key"
	
	/**
	Key for entry in userInfo dictionary of `kAPIError` notification.
	Contains a corresponding `NSError` object.
	*/
	public let MMNotificationKeyAPIErrorUserInfo = "com.mobile-messaging.notification.api-error-key"
	
	/**
	Key for entry in userInfo dictionary of `kMessageReceived` notification.
	Contains a remote notification payload.
	*/
	public let MMNotificationKeyMessagePayload = "com.mobile-messaging.notification.message-key"
	
	/**
	Key for entry in userInfo dictionary of `kMessageReceived` notification.
	Contains a flag that indicates whether the message is pushed by APNs or pulled from the server.
	*/
	public let MMNotificationKeyMessageIsPush = "com.mobile-messaging.notification.message-is-push-key"
	
	/**
	Key for entry in userInfo dictionary of `kMessageReceived` notification.
	Contains a flag that indicates whether the remote notification is a silent push.
	*/
	public let MMNotificationKeyMessageIsSilent = "com.mobile-messaging.notification.message-is-silent-key"

//MARK: Notifications
	/**
	The notification `kRegistrationUpdated` will be posted after the registration is updated on backend server.
	*/
	public let MMNotificationRegistrationUpdated = "com.mobile-messaging.notification.reg-updated"
	
	/**
	The notification `kDeviceTokenReceived` will be posted after the APNs device token is received.

	*/
	public let MMNotificationDeviceTokenReceived = "com.mobile-messaging.notification.device-token-received"
	
	/**
	The notification `kDeliveryReportSent` will be posted after the MobileMesaging library has succesfully sent message delivery report.
	*/
	public let MMNotificationDeliveryReportSent = "com.mobile-messaging.notification.dlr-sent"
	
	/**
	The notification `kAPIError` will be posted after receiving any error from server.
	*/
	public let MMNotificationAPIError = "com.mobile-messaging.notification.api-error"
	
	/**
	The notification `kMessageReceived` will be posted after receiving any message, either from APNs or the server.
	*/
	public let MMNotificationMessageReceived = "com.mobile-messaging.notification.message-received"