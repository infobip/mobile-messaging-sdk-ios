//
//  InstallationAttributeModels.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 29/11/2018.
//

import Foundation

struct DepersonalizationConsts {
	static var failuresNumberLimit = 3
}

@objc public enum SuccessPending: Int {
	case undefined = 0, pending, success
}

public final class Installation: NSObject, NSCoding, JSONDecodable, DictionaryRepresentable {
	/// If you have a users database where every user has a unique identifier, you would leverage our External User Id API to gather and link all users devices where your application is installed. However if you have several different applications that share a common user data base you would need to separate one push message destination from another (applications may be considered as destinations here). In order to do such message destination separation, you would need to provide us with a unique Application User Id.
	public var applicationUserId: String?

	/// Returns installations custom data. Arbitrary attributes that are related to the current installation. You can provide additional users information to the server, so that you will be able to send personalised targeted messages to exact user and other nice features.
	public var customAttributes: [String: AttributeType]?

	/// Primary device setting
	/// Single user profile on Infobip Portal can have one or more mobile devices with the application installed. You might want to mark one of such devices as a primary device and send push messages only to this device (i.e. receive bank authorization codes only on one device).
	public var isPrimaryDevice: Bool

	/// Current push registration status.
	/// The status defines whether the device is allowed to be receiving push notifications (regular push messages/geofencing campaign messages/messages fetched from the server).
	/// MobileMessaging SDK has the push registration enabled by default.
	public var isPushRegistrationEnabled: Bool

	/// Unique push registration identifier issued by server. This identifier matches one to one with APNS cloud token of the particular application installation. This identifier is only available after `MMNotificationRegistrationUpdated` event.
	public let pushRegistrationId: String?

	public let appVersion: String?
	public let deviceManufacturer: String?
	public let deviceModel: String?
	public let deviceName: String?
	public let deviceSecure: Bool
	public let deviceTimeZone: String?
	public let geoEnabled: Bool
	public let language: String?
	public let notificationsEnabled: Bool
	public let os: String?
	public let osVersion: String?
	public let pushServiceToken: String?
	public let pushServiceType: String?
	public let sdkVersion: String?
	// more properties needed? ok but look at the code below first.

	required public init?(coder aDecoder: NSCoder) {
		applicationUserId = aDecoder.decodeObject(forKey: "applicationUserId") as? String
		customAttributes = aDecoder.decodeObject(forKey: "customAttributes") as? [String: AttributeType]
		isPrimaryDevice = aDecoder.decodeBool(forKey: "isPrimary")
		isPushRegistrationEnabled = aDecoder.decodeBool(forKey: "regEnabled")
		pushRegistrationId = aDecoder.decodeObject(forKey: "pushRegId") as? String

		appVersion = aDecoder.decodeObject(forKey: "appVersion") as? String
		deviceManufacturer = aDecoder.decodeObject(forKey: "deviceManufacturer") as? String
		deviceModel = aDecoder.decodeObject(forKey: "deviceModel") as? String
		deviceName = aDecoder.decodeObject(forKey: "deviceName") as? String
		deviceSecure = aDecoder.decodeObject(forKey: "deviceSecure") as? Bool ?? false
		deviceTimeZone = aDecoder.decodeObject(forKey: "deviceTimeZone") as? String
		geoEnabled = aDecoder.decodeObject(forKey: "geoEnabled") as? Bool ?? false
		language = aDecoder.decodeObject(forKey: "language") as? String
		notificationsEnabled = aDecoder.decodeObject(forKey: "notificationsEnabled") as? Bool ?? true
		os = aDecoder.decodeObject(forKey: "os") as? String
		osVersion = aDecoder.decodeObject(forKey: "osVersion") as? String
		pushServiceToken = aDecoder.decodeObject(forKey: "pushServiceToken") as? String
		pushServiceType = aDecoder.decodeObject(forKey: "pushServiceType") as? String
		sdkVersion = aDecoder.decodeObject(forKey: "sdkVersion") as? String
	}

	public func encode(with aCoder: NSCoder) {
		aCoder.encode(applicationUserId, forKey: "applicationUserId")
		aCoder.encode(customAttributes, forKey: "customAttributes")
		aCoder.encode(isPrimaryDevice, forKey: "isPrimary")
		aCoder.encode(isPushRegistrationEnabled, forKey: "regEnabled")
		aCoder.encode(pushRegistrationId, forKey: "pushRegId")

		aCoder.encode(appVersion, forKey: "appVersion")
		aCoder.encode(deviceManufacturer, forKey: "deviceManufacturer")
		aCoder.encode(deviceModel, forKey: "deviceModel")
		aCoder.encode(deviceName, forKey: "deviceName")
		aCoder.encode(deviceSecure, forKey: "deviceSecure")
		aCoder.encode(deviceTimeZone, forKey: "deviceTimeZone")
		aCoder.encode(geoEnabled, forKey: "geoEnabled")
		aCoder.encode(language, forKey: "language")
		aCoder.encode(notificationsEnabled, forKey: "notificationsEnabled")
		aCoder.encode(os, forKey: "os")
		aCoder.encode(osVersion, forKey: "osVersion")
		aCoder.encode(pushServiceToken, forKey: "pushServiceToken")
		aCoder.encode(pushServiceType, forKey: "pushServiceType")
		aCoder.encode(sdkVersion, forKey: "sdkVersion")
	}

	convenience init?(json: JSON) {
		guard let pushRegId = json[Attributes.pushRegistrationId.requestPayloadKey].string else // a valid server response must contain pushregid
		{
			return nil
		}

		self.init(
			applicationUserId: json[Attributes.applicationUserId.requestPayloadKey].string,
			appVersion: json[Consts.SystemDataKeys.appVer].string,
			customAttributes: json[Attributes.customInstanceAttributes.requestPayloadKey].dictionary?.decodeCustomAttributesJSON,
			deviceManufacturer: json[Consts.SystemDataKeys.deviceManufacturer].string,
			deviceModel: json[Consts.SystemDataKeys.deviceModel].string,
			deviceName: json[Consts.SystemDataKeys.deviceName].string,
			deviceSecure: json[Consts.SystemDataKeys.deviceSecure].bool ?? false,
			deviceTimeZone: json[Consts.SystemDataKeys.deviceTimeZone].string,
			geoEnabled: json[Consts.SystemDataKeys.geofencingServiceEnabled].bool ?? false,
			isPrimaryDevice: json[Attributes.isPrimaryDevice.requestPayloadKey].bool ?? false,
			isPushRegistrationEnabled: json[Attributes.registrationEnabled.requestPayloadKey].bool ?? true,
			language: json[Consts.SystemDataKeys.language].string,
			notificationsEnabled: json[Consts.SystemDataKeys.notificationsEnabled].bool ?? true,
			os: json[Consts.SystemDataKeys.OS].string,
			osVersion: json[Consts.SystemDataKeys.osVer].string,
			pushRegistrationId: pushRegId,
			pushServiceToken: json[Attributes.pushServiceToken.requestPayloadKey].string,
			pushServiceType: json[Consts.SystemDataKeys.pushServiceType].string,
			sdkVersion: json[Consts.SystemDataKeys.sdkVersion].string
			)
	}

	init(applicationUserId: String?,
		 appVersion: String?,
		 customAttributes: [String: AttributeType]?,
		 deviceManufacturer: String?,
		 deviceModel: String?,
		 deviceName: String?,
		 deviceSecure: Bool,
		 deviceTimeZone: String?,
		 geoEnabled: Bool,
		 isPrimaryDevice: Bool,
		 isPushRegistrationEnabled: Bool,
		 language: String?,
		 notificationsEnabled: Bool,
		 os: String?,
		 osVersion: String?,
		 pushRegistrationId: String?,
		 pushServiceToken: String?,
		 pushServiceType: String?,
		 sdkVersion: String?)
	{
		self.applicationUserId = applicationUserId
		self.appVersion = appVersion
		self.customAttributes = customAttributes
		self.deviceManufacturer = deviceManufacturer
		self.deviceModel = deviceModel
		self.deviceName = deviceName
		self.deviceSecure = deviceSecure
		self.deviceTimeZone = deviceTimeZone
		self.geoEnabled = geoEnabled
		self.isPrimaryDevice = isPrimaryDevice
		self.isPushRegistrationEnabled = isPushRegistrationEnabled
		self.language = language
		self.notificationsEnabled = notificationsEnabled
		self.os = os
		self.osVersion = osVersion
		self.pushRegistrationId = pushRegistrationId
		self.pushServiceToken = pushServiceToken
		self.pushServiceType = pushServiceType
		self.sdkVersion = sdkVersion
	}

	public override func isEqual(_ object: Any?) -> Bool {
		guard let object = object as? Installation else {
			return false
		}

		return self.applicationUserId == object.applicationUserId &&
			self.appVersion == object.appVersion &&
			self.customAttributes == object.customAttributes &&
			self.deviceManufacturer == object.deviceManufacturer &&
			self.deviceModel == object.deviceModel &&
			self.deviceName == object.deviceName &&
			self.deviceSecure == object.deviceSecure &&
			self.deviceTimeZone == object.deviceTimeZone &&
			self.geoEnabled == object.geoEnabled &&
			self.isPrimaryDevice == object.isPrimaryDevice &&
			self.isPushRegistrationEnabled == object.isPushRegistrationEnabled &&
			self.language == object.language &&
			self.notificationsEnabled == object.notificationsEnabled &&
			self.os == object.os &&
			self.osVersion == object.osVersion &&
			self.pushRegistrationId == object.pushRegistrationId &&
			self.pushServiceToken == object.pushServiceToken &&
			self.pushServiceType == object.pushServiceType &&
			self.sdkVersion == object.sdkVersion

	}

	// must be extracted to cordova plugin srcs
	public convenience init?(dictRepresentation dict: DictionaryRepresentation) { // the dictionary only considered to come from js cordova plugin. key names must match properties names
		self.init(
			applicationUserId: dict["applicationUserId"] as? String,
			appVersion: dict["appVersion"] as? String,
			customAttributes: dict["customAttributes"] as? [String: AttributeType],
			deviceManufacturer: dict["deviceManufacturer"] as? String,
			deviceModel: dict["deviceModel"] as? String,
			deviceName: dict["deviceName"] as? String,
			deviceSecure: dict["deviceSecure"] as? Bool ?? false,
			deviceTimeZone: dict["deviceTimeZone"] as? String,
			geoEnabled: dict["geoEnabled"] as? Bool ?? false,
			isPrimaryDevice: dict["isPrimaryDevice"] as? Bool ?? false,
			isPushRegistrationEnabled: dict["isPushRegistrationEnabled"] as? Bool ?? true,
			language: dict["language"] as? String,
			notificationsEnabled: dict["notificationsEnabled"] as? Bool ?? true,
			os: dict["os"] as? String,
			osVersion: dict["osVersion"] as? String,
			pushRegistrationId: dict["pushRegistrationId"] as? String,
			pushServiceToken: dict["pushServiceToken"] as? String,
			pushServiceType: dict["pushServiceType"] as? String,
			sdkVersion: dict["sdkVersion"] as? String
		)
	}

	// must be extracted to cordova plugin srcs
	public var dictionaryRepresentation: DictionaryRepresentation {
		var dict = DictionaryRepresentation()
		dict["applicationUserId"] = applicationUserId
		dict["appVersion"] = appVersion
		dict["customAttributes"] = customAttributes
		dict["deviceManufacturer"] = deviceManufacturer
		dict["deviceModel"] = deviceModel
		dict["deviceName"] = deviceName
		dict["deviceSecure"] = deviceSecure
		dict["deviceTimeZone"] = deviceTimeZone
		dict["geoEnabled"] = geoEnabled
		dict["isPrimaryDevice"] = isPrimaryDevice
		dict["isPushRegistrationEnabled"] = isPushRegistrationEnabled
		dict["language"] = language
		dict["notificationsEnabled"] = notificationsEnabled
		dict["os"] = os
		dict["osVersion"] = osVersion
		dict["pushRegistrationId"] = pushRegistrationId
		dict["pushServiceToken"] = pushServiceToken
		dict["pushServiceType"] = pushServiceType
		dict["sdkVersion"] = sdkVersion
		return dict
	}
}
