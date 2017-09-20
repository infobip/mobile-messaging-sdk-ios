//
//  MMAPIKeysAndValues.swift
//  MobileMessaging
//
//  Created by okoroleva on 08.03.16.
//

import Foundation

struct APIKeys {
	static let kMessageId = "messageId"
	
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
	
	//MARK: MO Messages API
	static let kMOFailedMOMessageIDs = "failedMessageIDs"
	static let kMOFrom = "from"
	static let kMOMessages = "messages"
	static let kMODestination = "destination"
	static let kMOText = "text"
	static let kMOCustomPayload = "customPayload"
	static let kMOMessageId = "messageId"
	static let kMOMessageSentStatusCode = "statusCode"
    static let kMOBulkId = "bulkId"
    static let kMOInitialMessageId = "initialMessageId"
}

struct APIHeaders {
	static let foreground = "foreground"
	static let pushRegistrationId = "pushregistrationid"
}

struct VersionCheck {
	//MARK: Library Version API
	static let lastCheckDateKey = "com.mobile-messaging.library-version-check.last-check-date"
	static let platformType = "platformType"
	static let libraryVersion = "libraryVersion"
	static let libraryVersionUpdateUrl = "updateUrl"
}
struct PushRegistration {
	//MARK: Registration API
	static let isEnabled = "pushRegistrationEnabled"
	static let platform = "platformType"
	static let deviceToken = "registrationId"
	static let internalId = "deviceApplicationInstanceId"
	static let expiredInternalId = "expiredDeviceApplicationInstanceId"
}

struct SystemDataKeys {
	//MARK: SystemData API
	static let sdkVersion = "sdkVersion"
	static let osVer = "osVersion"
	static let deviceManufacturer = "deviceManufacturer"
	static let deviceModel = "deviceModel"
	static let appVer = "applicationVersion"
	static let geofencingServiceEnabled = "geofencing"
	static let notificationsEnabled = "notificationsEnabled"
    static let deviceSecure = "deviceSecure"
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
	static let messageIdsMap = "messageIds"
	static let sdkMessageId = "sdkMessageId"
	static let messages = "messages"
}

struct InternalDataKeys {
	static let event = "event"
	static let deliveryTime = "deliveryTime"
	static let silent = "silent"
	static let geo = "geo"
	static let messageTypeGeo = "geo"
	static let messageType = "messageType"
	static let attachments = "atts"
	static let sendDateTime = "sendDateTime"
    static let bulkId = "bulkId"
}

struct AttachmentsKeys {
	static let url = "url"
	static let type = "t"
}

struct DeliveryReport {
	static let dlrMessageIds = "dlrIds"
}

struct APNSPayloadKeys {
	//MARK: APNs
	static let payloads = "payloads"
	static let aps = "aps"
	static let alert = "alert"
	static let title = "title"
	static let body = "body"
	static let badge = "badge"
	static let sound = "sound"
	static let customPayload = "customPayload"
	static let internalData = "internalData"
	static let contentAvailable = "content-available"
	
	//MARK: Common fields
	static let messageId = "messageId"
}

struct APIValues {
	static let prodBaseURLString = "https://oneapi2.infobip.com"
	static let platformType = "APNS"
}
