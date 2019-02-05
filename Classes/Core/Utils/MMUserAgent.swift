//
//  UserAgent.swift
//
//  Created by Andrey K. on 08/07/16.
//

import Foundation
import CoreTelephony
import LocalAuthentication

func ==(lhs: SystemData, rhs: SystemData) -> Bool {
	return lhs.hashValue == rhs.hashValue
}
struct SystemData: Hashable {
	let SDKVersion, OSVer, deviceManufacturer, deviceModel, appVer, language, deviceName, os, pushServiceType: String
	let deviceTimeZone: String?
	let notificationsEnabled, deviceSecure: Bool
	var requestPayload: [String: AnyHashable] {

		var result : [String: AnyHashable] = [
			Consts.SystemDataKeys.geofencingServiceEnabled: false,
			Consts.SystemDataKeys.notificationsEnabled: notificationsEnabled,
			Consts.SystemDataKeys.sdkVersion: SDKVersion
		]
		if (!MobileMessaging.privacySettings.systemInfoSendingDisabled) {
			result[Consts.SystemDataKeys.osVer] = OSVer
			result[Consts.SystemDataKeys.deviceManufacturer] = deviceManufacturer
			result[Consts.SystemDataKeys.deviceModel] = deviceModel
			result[Consts.SystemDataKeys.appVer] = appVer
			result[Consts.SystemDataKeys.deviceSecure] = deviceSecure
			result[Consts.SystemDataKeys.language] = language
			result[Consts.SystemDataKeys.deviceName] = deviceName
			result[Consts.SystemDataKeys.OS] = os
			result[Consts.SystemDataKeys.pushServiceType] = pushServiceType
			result[Consts.SystemDataKeys.deviceTimeZone] = deviceTimeZone
		}
		return (result as [String: AnyHashable]).mm_applySubservicesSystemData()
	}
	
	var hashValue: Int {
		//we care only about values!
		return requestPayload.valuesStableHash
	}
}

@objcMembers
public class UserAgent: NSObject {
	public var cordovaPluginVersion: String?
	
	struct DataOptions : OptionSet {
		let rawValue: Int
		init(rawValue: Int = 0) { self.rawValue = rawValue }
		static let None = DataOptions(rawValue: 0)
		static let System = DataOptions(rawValue: 1 << 0)
		static let Carrier = DataOptions(rawValue: 1 << 1)
	}
	
	var systemData: SystemData {
		return SystemData(SDKVersion: libraryVersion.appending(cordovaPluginVersion == nil ? "" : " (cordova \(cordovaPluginVersion!))"), OSVer: osVersion, deviceManufacturer: deviceManufacturer, deviceModel: deviceModelName, appVer: hostingAppVersion, language: language, deviceName: deviceName, os: osName, pushServiceType: pushServiceType, deviceTimeZone: deviceTimeZone, notificationsEnabled: notificationsEnabled, deviceSecure: deviceSecure)
	}

	public var language: String {
		if let localeId = (UserDefaults.standard.object(forKey: "AppleLanguages") as? Array<String>)?.first ?? NSLocale.current.languageCode {
			return NSLocale.components(fromLocaleIdentifier: localeId)[NSLocale.Key.languageCode.rawValue] ?? ""
		} else {
			return ""
		}
	}
	
	public var notificationsEnabled: Bool {
		if itsToEarlyToCheckNotificationsEnabledStatus() {
			return true
		}
		guard let settings = MobileMessaging.application.currentUserNotificationSettings else {
			return true
		}
		return !settings.types.isEmpty
	}

	private func itsToEarlyToCheckNotificationsEnabledStatus() -> Bool {
		if let registrationTimestamp = MobileMessaging.sharedInstance?.internalData().registrationDate?.timeIntervalSince1970 {
			return (Date().timeIntervalSince1970 - registrationTimestamp) > 60*60*1 /*1 hr*/
		} else {
			return true
		}
	}
	
	public var osVersion: String {
		return UIDevice.current.systemVersion
	}
	
	public var osName: String {
		return UIDevice.current.systemName
	}

	public var libraryVersion: String {
		return (MobileMessaging.bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? mobileMessagingVersion)
	}
	
	public var libraryName: String {
		return MobileMessaging.bundle.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String ?? "MobileMessaging"
	}
	
	public var hostingAppVersion: String {
		return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
	}
	
	public var hostingAppName: String {
		return Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? ""
	}
	
	public var deviceManufacturer: String {
		return "Apple"
	}

	public var deviceName: String {
		return UIDevice.current.name
	}

	public var deviceModelName : String {
		let name = UnsafeMutablePointer<utsname>.allocate(capacity: 1)
		defer {
			name.deallocate()
		}
		uname(name)
		let machine = withUnsafePointer(to: &name.pointee.machine, { (machineNamePointer) -> String? in
			return machineNamePointer.withMemoryRebound(to: Int8.self, capacity: 256, { (p) -> String? in
				return String(validatingUTF8: p)
			})
		})
		// https://gist.github.com/adamawolf/3048717
		let machines = [
			"iPod1,1":"iPod Touch",
			"iPod2,1":"iPod Touch 2",
			"iPod3,1":"iPod Touch 3",
			"iPod4,1":"iPod Touch 4",
			"iPod5,1":"iPod Touch 5",
			"iPod7,1":"iPod Touch 6",

			"iPhone3,1":"iPhone 4 (GSM)",
			"iPhone3,2":"iPhone 4",
			"iPhone3,3":"iPhone 4 (CDMA)",
			"iPhone4,1":"iPhone 4s",
			"iPhone5,1":"iPhone 5 (GSM)",
			"iPhone5,2":"iPhone 5 (GSM+CDMA)",
			"iPhone5,3":"iPhone 5c (GSM)",
			"iPhone5,4":"iPhone 5c (GSM+CDMA)",
			"iPhone6,1":"iPhone 5s (GSM)",
			"iPhone6,2":"iPhone 5s (GSM+CDMA)",
			"iPhone7,2":"iPhone 6",
			"iPhone7,1":"iPhone 6 Plus",
			"iPhone8,1":"iPhone 6s",
			"iPhone8,2":"iPhone 6s Plus",
			"iPhone8,4":"iPhone SE",
			"iPhone9,1":"iPhone 7 (CDMA)",
			"iPhone9,3":"iPhone 7 (GSM)",
			"iPhone9,2":"iPhone 7 Plus (CDMA)",
			"iPhone9,4":"iPhone 7 Plus (GSM)",

			"iPhone10,1":"iPhone 8 (CDMA+GSM)",
			"iPhone10,2":"iPhone 8 Plus (CDMA+GSM)",
			"iPhone10,3":"iPhone X (CDMA+GSM)",
			"iPhone10,4":"iPhone 8 (GSM)",
			"iPhone10,5":"iPhone 8 Plus (GSM)",
			"iPhone10,6":"iPhone X (GSM)",

			"iPhone11,2":"iPhone XS",
			"iPhone11,4":"iPhone XS Max China",
			"iPhone11,6":"iPhone XS Max",
			"iPhone11,8":"iPhone XR",

			"iPad1,1":"iPad (Wifi)",
			"iPad1,2":"iPad (Cellular)",

			"iPad2,1":"iPad 2 (WiFi)",
			"iPad2,2":"iPad 2 (GSM)",
			"iPad2,3":"iPad 2 (CDMA)",
			"iPad2,4":"iPad 2 (WiFi Rev A)",
			"iPad2,5":"iPad Mini (WiFi)",
			"iPad2,6":"iPad Mini (GSM)",
			"iPad2,7":"iPad Mini (GSM+CDMA)",

			"iPad3,1":"iPad 3 (WiFi)",
			"iPad3,2":"iPad 3 (GSM)",
			"iPad3,3":"iPad 3 (GSM+CDMA)",
			"iPad3,4":"iPad 4 (WiFi)",
			"iPad3,5":"iPad 4 (GSM)",
			"iPad3,6":"iPad 4 (GSM+CDMA)",

			"iPad4,1":"iPad Air (WiFi)",
			"iPad4,2":"iPad Air (GSM)",
			"iPad4,3":"iPad Air (GSM+CDMA)",
			"iPad4,4":"iPad Mini 2 (WiFi)",
			"iPad4,5":"iPad Mini 2 (GSM)",
			"iPad4,6":"iPad Mini 2 (GSM+CDMA)",
			"iPad4,7":"iPad Mini 3 (WiFi)",
			"iPad4,8":"iPad Mini 3 (GSM)",
			"iPad4,9":"iPad Mini 3 (GSM+CDMA)",

			"iPad5,1":"iPad Mini 4 (WiFi)",
			"iPad5,2":"iPad Mini 4 (GSM)",
			"iPad5,3":"iPad Air 2 (WiFi)",
			"iPad5,4":"iPad Air 2 (GSM)",

			"iPad6,3":"iPad Pro (12.9, WiFi)",
			"iPad6,4":"iPad Pro (12.9, GSM)",
			"iPad6,7":"iPad Pro (9.7, WiFi)",
			"iPad6,8":"iPad Pro (9.7, GSM)",
			"iPad6,11":"iPad 5 (WiFi)",
			"iPad6,12":"iPad 5 (GSM)",

			"iPad7,1":"iPad Pro 2 (12.9, WiFi)",
			"iPad7,2":"iPad Pro 2 (12.9, GSM)",
			"iPad7,3":"iPad Pro (10.5, WiFi)",
			"iPad7,4":"iPad Pro (10.5, GSM)",
			"iPad7,5":"iPad 6 (WiFi)",
			"iPad7,6":"iPad 6 (GSM)",

			"iPad8,1":"iPad Pro 3 (11, WiFi)",
			"iPad8,2":"iPad Pro 3 (11, WiFi)",
			"iPad8,3":"iPad Pro 3 (11, GSM)",
			"iPad8,4":"iPad Pro 3 (11, GSM)",
			"iPad8,5":"iPad Pro 3 (12.9, WiFi)",
			"iPad8,6":"iPad Pro 3 (12.9, WiFi)",
			"iPad8,7":"iPad Pro 3 (12.9, GSM)",
			"iPad8,8":"iPad Pro 3 (12.9, GSM)",

			"i386":"32-bit Simulator",
			"x86_64":"64-bit Simulator"
		]
		if let machine = machine {
			return machines[machine] ?? UIDevice.current.localizedModel
		} else {
			return UIDevice.current.localizedModel
		}
	}

	public var deviceSecure: Bool {
		if #available(iOS 9.0, *) {
			return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
		} else {
			if let secret = "Device has passcode set?".data(using: String.Encoding.utf8, allowLossyConversion: false) {
				let attributes = [kSecClass as String:kSecClassGenericPassword,
								  kSecAttrService as String:"LocalDeviceServices",
								  kSecAttrAccount as String:"NoAccount",
								  kSecValueData as String:secret,
								  kSecAttrAccessible as String:kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly] as [String : Any]

				let status = SecItemAdd(attributes as CFDictionary, nil)
				if status == 0 {
					SecItemDelete(attributes as CFDictionary)
					return true
				}
			}
			return false
		}
	}

	public var deviceTimeZone: String? {
		return MobileMessaging.timeZone.abbreviation()
	}

	public var pushServiceType: String {
		return Consts.APIValues.platformType
	}

	var currentUserAgentString: String {
		var options = [UserAgent.DataOptions.None]
		if !(MobileMessaging.privacySettings.systemInfoSendingDisabled) {
			options.append(UserAgent.DataOptions.System)
		}
		if !(MobileMessaging.privacySettings.carrierInfoSendingDisabled) {
			options.append(UserAgent.DataOptions.Carrier)
		}
		return userAgentString(withOptions: options)
	}

	func userAgentString(withOptions options: [DataOptions]) -> String {
		func systemDataString(allowed: Bool) -> String {
			let outputOSName = allowed ? osName : ""
			let outputOSVersion = allowed ? osVersion : ""
			let outputDeviceModel = allowed ? deviceModelName : ""
			let osArch = ""
			let deviceManufacturer = ""
			let deviceNameS = allowed ? deviceName : ""
			let outputHostingAppName = allowed ? hostingAppName : ""
			let outputHostingAppVersion = allowed ? hostingAppVersion : ""

			let result = "\(libraryName)/\(libraryVersion.appending(cordovaPluginVersion == nil ? "" : "-cordova-\(cordovaPluginVersion!)"))(\(outputOSName);\(outputOSVersion);\(osArch);\(outputDeviceModel);\(deviceManufacturer);\(outputHostingAppName);\(outputHostingAppVersion);\(deviceNameS)"
			
			return result
		}
		
		func carrierDataString(allowed: Bool) -> String {
			let networkInfo = CTTelephonyNetworkInfo()
			let carrier = allowed ? networkInfo.subscriberCellularProvider : nil
			
			let mobileCarrierName = carrier?.carrierName ?? ""
			let mobileCountryCode = carrier?.mobileCountryCode ?? ""
			let mobileNetworkCode = carrier?.mobileNetworkCode ?? ""
			
			return ";\(mobileCarrierName);\(mobileNetworkCode);\(mobileCountryCode)"
		}
		
		return systemDataString(allowed: options.contains(UserAgent.DataOptions.System)) + carrierDataString(allowed: options.contains(UserAgent.DataOptions.Carrier)) + ")"
	}
}

extension Dictionary where Key: ExpressibleByStringLiteral, Value: Hashable {
	func mm_applySubservicesSystemData() -> [Key: Value] {
		guard let mmContext = MobileMessaging.sharedInstance else {
			return self
		}
		return mmContext.subservices.reduce(self, { (result, kv) -> [Key: Value] in
			guard let serviceSystemData = kv.value.systemData as? [Key: Value] else {
				return result
			}
			var ret = result
			ret = ret + serviceSystemData
			return ret
		})
	}
}
