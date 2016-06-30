//
//  MMAPIKeysAndValues.swift
//  MobileMessaging
//
//  Created by okoroleva on 08.03.16.
//

import Foundation

struct MMAPIKeys {
	//MARK: API availability
//	static let kFetchAPIEnabled = true
//	static let kSeenAPIEnabled = true
	
    //MARK: registration
    static let kPlatformType = "platformType"
    static let kRegistrationId = "registrationId"
    static let kInternalRegistrationId = "deviceApplicationInstanceId"
    
    //MARK: delivery
    static let kMessageIDs = "messageIDs"
	
    //MARK: serviceErrors
	static let kBackendErrorDomain = "com.mobile-messaging.backend"
    static let kRequestError = "requestError"
    static let kServiceException = "serviceException"
    static let kErrorText = "text"
	static let kErrorMessageId = "messageId"
    
    //MARK: APNs
    static let kPayloads = "payloads"
    static let kAps = "aps"
    static let kAlert = "alert"
    static let kTitle = "title"
    static let kBody = "body"
    static let kBadge = "badge"
    static let kSound = "sound"
    static let kCustomPayload = "applicationData"
	static let kContentAvailable = "content-available"
	static let kInternalData = "internalData"
	static let kSilent = "silent"
	
	//MARK: email
	static let kEmail = "email"
	
	//MARK: msisdn
	static let kMSISDN = "msisdn"
    
    //MARK: seenMessages
    static let kSeenMessages = "messages"
    static let kSeenTimestampDelta = "timestampDelta"
    
    //MARK: Common fields
    static let kMessageId = "messageId"
	
	//MARK: Sync API
	static let kArchiveMsgIds = "mIDs"
	static let kDLRMsgIds = "drIDs"
}

struct MMAPIValues {
	static let kProdBaseURLString = "https://oneapi.infobip.com"	
	static let kPlatformType = "APNS"
}