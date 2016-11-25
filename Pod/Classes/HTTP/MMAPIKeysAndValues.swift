//
//  MMAPIKeysAndValues.swift
//  MobileMessaging
//
//  Created by okoroleva on 08.03.16.
//

import Foundation

struct MMAPIKeys {
	static let kMessageId = "messageId"
	
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

	//MARK: seenMessages
    static let kSeenMessages = "messages"
    static let kSeenTimestampDelta = "timestampDelta"
	
	//MARK: Sync API
	static let kArchiveMsgIds = "mIDs"
	static let kDLRMsgIds = "drIDs"
	
	//MARK: UserData API
	static let kUserDataPredefinedUserData = "predefinedUserData"
	static let kUserDataCustomUserData = "customUserData"
	static let kUserDataExternalUserId = "externalUserId"
	static let kUserDataFailures = "failures"
	
	//MARK: SystemData API
	static let kSystemDataSDKVersion = "sdkVersion"
	static let kSystemDataOSVer = "osVersion"
	static let kSystemDataDeviceManufacturer = "deviceManufacturer"
	static let kSystemDataDeviceModel = "deviceModel"
	static let kSystemDataAppVer = "applicationVersion"
	static let kSystemDataGeoAvailability = "geofencing"
	
	
	//MARK: MO Messages API
	static let kMOFailedMOMessageIDs = "failedMessageIDs"
	static let kMOFrom = "from"
	static let kMOMessages = "messages"
	static let kMODestination = "destination"
	static let kMOText = "text"
	static let kMOCustomPayload = "customPayload"
	static let kMOMessageId = "messageId"
	static let kMOMessageSentStatusCode = "statusCode"

	//MARK: Library Version API
	static let kLibraryVersionPlatformType = "platformType"
	static let kLibraryVersionLibraryVersion = "libraryVersion"
	static let kLibraryVersionUpdateUrl = "updateUrl"
}

struct GeoReportingAPIKeys {
	static let reports = "reports"
	static let event = "event"
	static let geoAreaId = "geoAreaId"
	static let campaignId = "campaignId"
	static let messageId = "messageId"
	static let timestampDelta = "timestampDelta"
	static let finishedCampaignIds = "finishedCampaignIds"
	static let suspendedCampaignIds = "suspendedCampaignIds"
}

struct APNSPayloadKeys {
	//MARK: Internal Data Keys
	static let kInternalDataEvent = "event"
	static let kInternalDataDeliveryTime = "deliveryTime"
	static let kInternalData: String = "internalData"
	static let kInternalDataSilent: String = "silent"
	static let kInternalDataGeo = "geo"
	static let kInternalDataMessageTypeGeo = "geo"
	static let kInternalDataMessageType = "messageType"
	
	//MARK: APNs
	static let kPayloads = "payloads"
	static let kAps = "aps"
	static let kAlert = "alert"
	static let kTitle = "title"
	static let kBody = "body"
	static let kBadge = "badge"
	static let kSound = "sound"
	static let kCustomPayload = "customPayload"
	static let kContentAvailable = "content-available"
	
	//MARK: Common fields
	static let kMessageId = "messageId"
}

struct MMAPIValues {
	static let kProdBaseURLString = "https://oneapi2.infobip.com"
	static let kPlatformType = "APNS"
}
