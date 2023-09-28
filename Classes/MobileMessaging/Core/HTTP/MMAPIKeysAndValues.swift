//
//  MMAPIKeysAndValues.swift
//  MobileMessaging
//
//  Created by okoroleva on 08.03.16.
//

import Foundation

internal typealias Consts = MMConsts
public struct MMConsts {

	struct UserSessions {
		static let sessionTimeoutSec = 30.0
		static let sessionSaveInterval = 5.0
		static let sessionStarts = "sessionStarts"
		static let sessionBounds = "sessionBounds"
	}

	struct Interaction {
		struct ActionKeys {
			static let identifier = "identifier"
			static let title = "title"
			static let titleLocalizationKey = "titleLocalizationKey"
			static let foreground = "foreground"
			static let authenticationRequired = "authenticationRequired"
			static let moRequired = "moRequired"
			static let destructive = "destructive"
			static let mm_prefix = "mm_"
			static let textInputActionButtonTitle = "textInputActionButtonTitle"
			static let textInputPlaceholder = "textInputPlaceholder"
		}

		static let actionHandlingTimeout = 20
	}

	static let UUIDRegexPattern = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"

	struct MessageFetchingSettings {
		static let messageArchiveLengthDays: Double = 7 // consider messages not older than N days
		static let fetchLimit = 100 // consider N most recent messages
		static let fetchingIterationLimit = 2 // fetching may trigger message handling, which in turn may trigger message fetching. This constant is here to break possible inifinite recursion.
	}

	struct KeychainKeys {
		static let prefix = "com.mobile-messaging"
		static let pushRegId = "internalId"
	}

	struct DynamicBaseUrlConsts {
		static let newBaseUrlHeader = "New-Base-URL"
		static let storedDynamicBaseUrlKey = "com.mobile-messaging.dynamic-base-url"
	}

	public struct APIKeys {
		public static let messageId = "messageId"

		//MARK: delivery
		static let messageIDs = "messageIDs"

		//MARK: serviceErrors
		static let backendErrorDomain = "com.mobile-messaging.backend"
		static let requestError = "requestError"
		static let serviceException = "serviceException"
		static let errorText = "text"
		static let errorMessageId = "messageId"

		//MARK: seenMessages
		public static let seenMessages = "messages"
		public static let seenTimestampDelta = "timestampDelta"
        public static let seenMessageInbox = "inbox"
        public static let seenExternalUserId = "externalUserId"

		//MARK: Sync API
		static let archiveMsgIds = "mIDs"
		static let DLRMsgIds = "drIDs"

		//MARK: MO Messages API
		struct MO {
			static let failedMOMessageIDs = "failedMessageIDs"
			static let from = "from"
			static let messages = "messages"
			static let destination = "destination"
			static let text = "text"
			static let customPayload = "customPayload"
			static let messageId = "messageId"
			static let messageSentStatusCode = "statusCode"
			static let bulkId = "bulkId"
			static let initialMessageId = "initialMessageId"
		}
	}

	struct APIHeaders {
		static let foreground = "foreground"
		static let pushRegistrationId = "pushregistrationid"
		static let applicationcode = "applicationcode"
	}
    
    struct BaseUrlRecovery {
        static let lastCheckDateKey = "com.mobile-messaging.base-url-validation.last-check-date"
        static let baseUrl = "baseUrl"
    }

	struct VersionCheck {
		//MARK: Library Version API
		static let lastCheckDateKey = "com.mobile-messaging.library-version-check.last-check-date"
		static let platformType = "platformType"
		static let libraryVersion = "libraryVersion"
		static let libraryVersionUpdateUrl = "updateUrl"
	}
	public struct PushRegistration {
		//MARK: Registration API
        public static let isEnabled = "pushRegistrationEnabled"
		public static let platform = "platformType"
        public static let deviceToken = "registrationId"
		public static let internalId = "deviceApplicationInstanceId"
        public static let expiredInternalId = "expiredDeviceApplicationInstanceId"
	}

	public struct SystemDataKeys {
		//MARK: SystemData API
		static let sdkVersion = "sdkVersion"
		static let osVer = "osVersion"
		static let deviceManufacturer = "deviceManufacturer"
		static let deviceModel = "deviceModel"
		static let appVer = "appVersion"
		public static let geofencingServiceEnabled = "geoEnabled"
		static let notificationsEnabled = "notificationsEnabled"
		static let deviceSecure = "deviceSecure"
		static let language = "language"
		static let deviceName = "deviceName"
		static let OS = "os"
		static let deviceTimeZone = "deviceTimezoneOffset"
		static let pushServiceType = "pushServiceType"
	}
    
    public struct InboxKeys {
        public static let messageTopic = "messageTopic"
        public static let dateTimeFrom = "dateTimeFrom"
        public static let dateTimeTo = "dateTimeTo"
        public static let limit = "limit"
        public static let messages = "messages"
        public static let countTotal = "countTotal"
        public static let countUnread = "countUnread"
    }

	public struct GeoReportingAPIKeys {
        public static let reports = "reports"
        public static let event = "event"
        public static let geoAreaId = "geoAreaId"
        public static let campaignId = "campaignId"
        public static let messageId = "messageId"
        public static let timestampDelta = "timestampDelta"
        public static let finishedCampaignIds = "finishedCampaignIds"
        public static let suspendedCampaignIds = "suspendedCampaignIds"
        public static let messageIdsMap = "messageIds"
        public static let sdkMessageId = "sdkMessageId"
        public static let messages = "messages"
	}

	public struct InternalDataKeys {
        public static let event = "event"
        public static let deliveryTime = "deliveryTime"
        public static let silent = "silent"
        public static let geo = "geo"
        public static let messageTypeGeo = "geo"
        public static let messageType = "messageType"
        public static let attachments = "atts"
        public static let sendDateTime = "sendDateTime"
        public static let bulkId = "bulkId"
        public static let showInApp = "inApp"
        public static let inAppStyle = "inAppStyle"
        public static let inAppExpiryDateTime = "inAppExpiryDateTime"
        public static let webViewUrl = "webViewUrl"
        public static let browserUrl = "browserUrl"
        public static let deeplink = "deeplink"
        public static let inAppDismissTitle = "inAppDismissTitle"
        public static let inAppOpenTitle = "inAppOpenTitle"
        public static let topic = "topic"
        public static let inbox = "inbox"
        public static let seen = "seen"
        public static let inAppDetails = "inAppDetails"
	}
    
    struct InAppDetailsKeys {
        static let url = "url"
        static let position = "position"
        static let type = "type"
    }

	struct Attachments {
		struct Keys {
			static let url = "url"
			static let type = "t"
		}
	}

	struct DeliveryReport {
		static let dlrMessageIds = "dlrIds"
	}

	public struct APNSPayloadKeys {
		//MARK: APNs
		static let payloads = "payloads"
		public static let aps = "aps"
		static let alert = "alert"
		static let title = "title"
		static let body = "body"
		static let badge = "badge"
		static let sound = "sound"
		static let customPayload = "customPayload"
		public static let internalData = "internalData"
		static let contentAvailable = "content-available"

		//MARK: Common fields
		public static let messageId = "messageId"
	}

	public struct APIValues {
		public static let prodDynamicBaseURLString = "https://mobile.infobip.com"
        static let amgDynamicBaseURLString = "https://api.infobip.com"
		public static let platformType = "APNS"
		
		struct MessageTypeValues {
			static let chat = "chat"
		}
	}

	struct SDKSettings {
		static var messagesRetentionPeriod: TimeInterval = 2 * 7 * 24 * 60 * 60 //two weeks
	}
}

enum Attributes : String {
	case pushServiceToken = "pushServiceToken"
	case customAttributes = "customAttributes"
	case externalUserId = "externalUserId"
	case registrationEnabled = "regEnabled"
	case applicationCode = "applicationCode"
	case badgeNumber = "badgeNumber"
	case systemDataHash = "systemDataHash"
	case location = "location"
	case pushRegistrationId = "pushRegId"
	case isPrimaryDevice = "isPrimary"
	case logoutStatusValue = "logoutStatusValue"
	case logoutFailCounter = "logoutFailCounter"
	case phones = "phones"
	case firstName = "firstName"
	case lastName = "lastName"
	case middleName = "middleName"
	case gender = "gender"
	case birthday = "birthday"
	case emails = "emails"
	case tags = "tags"
	case instances = "instances"
	case applicationUserId = "applicationUserId"
}
