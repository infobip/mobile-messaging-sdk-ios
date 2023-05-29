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

	struct APIKeys {
		static let messageId = "messageId"

		//MARK: delivery
		static let messageIDs = "messageIDs"

		//MARK: serviceErrors
		static let backendErrorDomain = "com.mobile-messaging.backend"
		static let requestError = "requestError"
		static let serviceException = "serviceException"
		static let errorText = "text"
		static let errorMessageId = "messageId"

		//MARK: seenMessages
		static let seenMessages = "messages"
		static let seenTimestampDelta = "timestampDelta"
        static let seenMessageInbox = "inbox"
        static let seenExternalUserId = "externalUserId"

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
		static let appVer = "appVersion"
		static let geofencingServiceEnabled = "geoEnabled"
		static let notificationsEnabled = "notificationsEnabled"
		static let deviceSecure = "deviceSecure"
		static let language = "language"
		static let deviceName = "deviceName"
		static let OS = "os"
		static let deviceTimeZone = "deviceTimezoneOffset"
		static let pushServiceType = "pushServiceType"
	}
    
    struct InboxKeys {
        static let messageTopic = "messageTopic"
        static let dateTimeFrom = "dateTimeFrom"
        static let dateTimeTo = "dateTimeTo"
        static let limit = "limit"
        static let messages = "messages"
        static let countTotal = "countTotal"
        static let countUnread = "countUnread"
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
		static let showInApp = "inApp"
		static let inAppStyle = "inAppStyle"
		static let inAppExpiryDateTime = "inAppExpiryDateTime"
		static let webViewUrl = "webViewUrl"
        static let browserUrl = "browserUrl"
        static let deeplink = "deeplink"
		static let inAppDismissTitle = "inAppDismissTitle"
		static let inAppOpenTitle = "inAppOpenTitle"
        static let topic = "topic"
        static let inbox = "inbox"
        static let seen = "seen"
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

	public struct APIValues {
		public static let prodDynamicBaseURLString = "https://mobile.infobip.com"
        static let amgDynamicBaseURLString = "https://api.infobip.com"
		static let platformType = "APNS"
		
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
