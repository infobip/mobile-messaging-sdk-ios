//
//  UserAgent.swift
//
//  Created by Andrey K. on 08/07/16.
//

import Foundation
import CoreTelephony
import LocalAuthentication

func ==(lhs: SystemData, rhs: SystemData) -> Bool {
	return lhs.stableHashValue == rhs.stableHashValue
}
struct SystemData {
	let SDKVersion, OSVer, deviceManufacturer, deviceModel, appVer, language, deviceName, os, pushServiceType: String
	let deviceTimeZone: String?
    let notificationsEnabled: Bool?
    let deviceSecure: Bool
	var requestPayload: [String: AnyHashable] {

		var result : [String: AnyHashable] = [
			Consts.SystemDataKeys.geofencingServiceEnabled: false,
			Consts.SystemDataKeys.sdkVersion: SDKVersion,
			Consts.SystemDataKeys.pushServiceType: pushServiceType,
			Consts.SystemDataKeys.OS: os,
			Consts.SystemDataKeys.osVer: OSVer,
			Consts.SystemDataKeys.deviceManufacturer: deviceManufacturer
		]

        result[Consts.SystemDataKeys.notificationsEnabled] = notificationsEnabled

		if (!MobileMessaging.privacySettings.systemInfoSendingDisabled) {
			result[Consts.SystemDataKeys.deviceModel] = deviceModel
			result[Consts.SystemDataKeys.appVer] = appVer
			result[Consts.SystemDataKeys.deviceSecure] = deviceSecure
			result[Consts.SystemDataKeys.language] = language
			result[Consts.SystemDataKeys.deviceName] = deviceName
			result[Consts.SystemDataKeys.deviceTimeZone] = deviceTimeZone
		}
		return (result as [String: AnyHashable]).mm_applySubservicesSystemData()
	}

	var stableHashValue: Int {
		//we care only about values!
		return requestPayload.valuesStableHash
	}
}

@objcMembers
public class MMUserAgent: NSObject {
	public var pluginVersion: String?

	struct DataOptions : OptionSet {
		let rawValue: Int
		init(rawValue: Int = 0) { self.rawValue = rawValue }
		static let None = DataOptions([])
		static let System = DataOptions(rawValue: 1 << 0)
		static let Carrier = DataOptions(rawValue: 1 << 1)
	}

	var systemData: SystemData {
		return SystemData(SDKVersion: libraryVersion.appending(pluginVersion == nil ? "" : " (\(pluginVersion!))"), OSVer: osVersion, deviceManufacturer: deviceManufacturer, deviceModel: deviceModelName, appVer: hostingAppVersion, language: language, deviceName: deviceName, os: osName, pushServiceType: pushServiceType, deviceTimeZone: deviceTimeZone, notificationsEnabled: notificationsEnabled, deviceSecure: deviceSecure)
	}

	public var language: String {
		if let localeId = (UserDefaults.standard.object(forKey: "AppleLanguages") as? Array<String>)?.first ?? NSLocale.current.languageCode {
			return NSLocale.components(fromLocaleIdentifier: localeId)[NSLocale.Key.languageCode.rawValue] ?? ""
		} else {
			return ""
		}
	}

	public var notificationsEnabled: Bool? {
		if itsTimeToCheckNotificationsEnabledStatus() {
			return MobileMessaging.application.notificationEnabled
		} else {
			return true
		}
	}

	private func itsTimeToCheckNotificationsEnabledStatus() -> Bool {
		if let registrationTimestamp = MobileMessaging.sharedInstance?.internalData().registrationDate?.timeIntervalSince1970 {
			return (MobileMessaging.date.now.timeIntervalSince1970 - registrationTimestamp) > 60*60*1 /*1 hr*/
		} else {
			return false
		}
	}

	public var osVersion: String {
		return UIDevice.current.systemVersion
	}

	public var osName: String {
		return "iOS"
	}

	public var libraryVersion: String {
        return MMVersion.mobileMessagingVersion
	}

	public var libraryName: String {
		return "MobileMessaging"
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
			"i386":"iPhone Simulator",
			"x86_64":"iPhone Simulator",
			"arm64":"iPhone Simulator",
			"iPhone1,1":"iPhone",
			"iPhone1,2":"iPhone 3G",
			"iPhone2,1":"iPhone 3GS",
			"iPhone3,1":"iPhone 4",
			"iPhone3,2":"iPhone 4 GSM Rev A",
			"iPhone3,3":"iPhone 4 CDMA",
			"iPhone4,1":"iPhone 4S",
			"iPhone5,1":"iPhone 5 (GSM)",
			"iPhone5,2":"iPhone 5 (GSM+CDMA)",
			"iPhone5,3":"iPhone 5C (GSM)",
			"iPhone5,4":"iPhone 5C (Global)",
			"iPhone6,1":"iPhone 5S (GSM)",
			"iPhone6,2":"iPhone 5S (Global)",
			"iPhone7,1":"iPhone 6 Plus",
			"iPhone7,2":"iPhone 6",
			"iPhone8,1":"iPhone 6s",
			"iPhone8,2":"iPhone 6s Plus",
			"iPhone8,4":"iPhone SE (GSM)",
			"iPhone9,1":"iPhone 7",
			"iPhone9,2":"iPhone 7 Plus",
			"iPhone9,3":"iPhone 7",
			"iPhone9,4":"iPhone 7 Plus",
			"iPhone10,1":"iPhone 8",
			"iPhone10,2":"iPhone 8 Plus",
			"iPhone10,3":"iPhone X Global",
			"iPhone10,4":"iPhone 8",
			"iPhone10,5":"iPhone 8 Plus",
			"iPhone10,6":"iPhone X GSM",
			"iPhone11,2":"iPhone XS",
			"iPhone11,4":"iPhone XS Max",
			"iPhone11,6":"iPhone XS Max Global",
			"iPhone11,8":"iPhone XR",
			"iPhone12,1":"iPhone 11",
			"iPhone12,3":"iPhone 11 Pro",
			"iPhone12,5":"iPhone 11 Pro Max",
			"iPhone12,8":"iPhone SE 2nd Gen",
			"iPhone13,1":"iPhone 12 Mini",
			"iPhone13,2":"iPhone 12",
			"iPhone13,3":"iPhone 12 Pro",
			"iPhone13,4":"iPhone 12 Pro Max",
			"iPhone14,2":"iPhone 13 Pro",
			"iPhone14,3":"iPhone 13 Pro Max",
			"iPhone14,4":"iPhone 13 Mini",
			"iPhone14,5":"iPhone 13",
			"iPhone14,6":"iPhone SE 3rd Gen",
			"iPhone14,7":"iPhone 14",
			"iPhone14,8":"iPhone 14 Plus",
			"iPhone15,2":"iPhone 14 Pro",
			"iPhone15,3":"iPhone 14 Pro Max",
			"iPod1,1":"1st Gen iPod",
			"iPod2,1":"2nd Gen iPod",
			"iPod3,1":"3rd Gen iPod",
			"iPod4,1":"4th Gen iPod",
			"iPod5,1":"5th Gen iPod",
			"iPod7,1":"6th Gen iPod",
			"iPod9,1":"7th Gen iPod",
			"iPad1,1":"iPad",
			"iPad1,2":"iPad 3G",
			"iPad2,1":"2nd Gen iPad",
			"iPad2,2":"2nd Gen iPad GSM",
			"iPad2,3":"2nd Gen iPad CDMA",
			"iPad2,4":"2nd Gen iPad New Revision",
			"iPad3,1":"3rd Gen iPad",
			"iPad3,2":"3rd Gen iPad CDMA",
			"iPad3,3":"3rd Gen iPad GSM",
			"iPad2,5":"iPad mini",
			"iPad2,6":"iPad mini GSM+LTE",
			"iPad2,7":"iPad mini CDMA+LTE",
			"iPad3,4":"4th Gen iPad",
			"iPad3,5":"4th Gen iPad GSM+LTE",
			"iPad3,6":"4th Gen iPad CDMA+LTE",
			"iPad4,1":"iPad Air (WiFi)",
			"iPad4,2":"iPad Air (GSM+CDMA)",
			"iPad4,3":"1st Gen iPad Air (China)",
			"iPad4,4":"iPad mini Retina (WiFi)",
			"iPad4,5":"iPad mini Retina (GSM+CDMA)",
			"iPad4,6":"iPad mini Retina (China)",
			"iPad4,7":"iPad mini 3 (WiFi)",
			"iPad4,8":"iPad mini 3 (GSM+CDMA)",
			"iPad4,9":"iPad Mini 3 (China)",
			"iPad5,1":"iPad mini 4 (WiFi)",
			"iPad5,2":"4th Gen iPad mini (WiFi+Cellular)",
			"iPad5,3":"iPad Air 2 (WiFi)",
			"iPad5,4":"iPad Air 2 (Cellular)",
			"iPad6,3":"iPad Pro (9.7 inch, WiFi)",
			"iPad6,4":"iPad Pro (9.7 inch, WiFi+LTE)",
			"iPad6,7":"iPad Pro (12.9 inch, WiFi)",
			"iPad6,8":"iPad Pro (12.9 inch, WiFi+LTE)",
			"iPad6,11":"iPad (2017)",
			"iPad6,12":"iPad (2017)",
			"iPad7,1":"iPad Pro 2nd Gen (WiFi)",
			"iPad7,2":"iPad Pro 2nd Gen (WiFi+Cellular)",
			"iPad7,3":"iPad Pro 10.5-inch 2nd Gen",
			"iPad7,4":"iPad Pro 10.5-inch 2nd Gen",
			"iPad7,5":"iPad 6th Gen (WiFi)",
			"iPad7,6":"iPad 6th Gen (WiFi+Cellular)",
			"iPad7,11":"iPad 7th Gen 10.2-inch (WiFi)",
			"iPad7,12":"iPad 7th Gen 10.2-inch (WiFi+Cellular)",
			"iPad8,1":"iPad Pro 11 inch 3rd Gen (WiFi)",
			"iPad8,2":"iPad Pro 11 inch 3rd Gen (1TB, WiFi)",
			"iPad8,3":"iPad Pro 11 inch 3rd Gen (WiFi+Cellular)",
			"iPad8,4":"iPad Pro 11 inch 3rd Gen (1TB, WiFi+Cellular)",
			"iPad8,5":"iPad Pro 12.9 inch 3rd Gen (WiFi)",
			"iPad8,6":"iPad Pro 12.9 inch 3rd Gen (1TB, WiFi)",
			"iPad8,7":"iPad Pro 12.9 inch 3rd Gen (WiFi+Cellular)",
			"iPad8,8":"iPad Pro 12.9 inch 3rd Gen (1TB, WiFi+Cellular)",
			"iPad8,9":"iPad Pro 11 inch 4th Gen (WiFi)",
			"iPad8,10":"iPad Pro 11 inch 4th Gen (WiFi+Cellular)",
			"iPad8,11":"iPad Pro 12.9 inch 4th Gen (WiFi)",
			"iPad8,12":"iPad Pro 12.9 inch 4th Gen (WiFi+Cellular)",
			"iPad11,1":"iPad mini 5th Gen (WiFi)",
			"iPad11,2":"iPad mini 5th Gen",
			"iPad11,3":"iPad Air 3rd Gen (WiFi)",
			"iPad11,4":"iPad Air 3rd Gen",
			"iPad11,6":"iPad 8th Gen (WiFi)",
			"iPad11,7":"iPad 8th Gen (WiFi+Cellular)",
			"iPad12,1":"iPad 9th Gen (WiFi)",
			"iPad12,2":"iPad 9th Gen (WiFi+Cellular)",
			"iPad14,1":"iPad mini 6th Gen (WiFi)",
			"iPad14,2":"iPad mini 6th Gen (WiFi+Cellular)",
			"iPad13,1":"iPad Air 4th Gen (WiFi)",
			"iPad13,2":"iPad Air 4th Gen (WiFi+Cellular)",
			"iPad13,4":"iPad Pro 11 inch 5th Gen",
			"iPad13,5":"iPad Pro 11 inch 5th Gen",
			"iPad13,6":"iPad Pro 11 inch 5th Gen",
			"iPad13,7":"iPad Pro 11 inch 5th Gen",
			"iPad13,8":"iPad Pro 12.9 inch 5th Gen",
			"iPad13,9":"iPad Pro 12.9 inch 5th Gen",
			"iPad13,10":"iPad Pro 12.9 inch 5th Gen",
			"iPad13,11":"iPad Pro 12.9 inch 5th Gen",
			"iPad13,16":"iPad Air 5th Gen (WiFi)",
			"iPad13,17":"iPad Air 5th Gen (WiFi+Cellular)",
			"iPad13,18":"iPad 10th Gen",
			"iPad13,19":"iPad 10th Gen",
			"iPad14,3":"iPad Pro 11 inch 4th Gen",
			"iPad14,4":"iPad Pro 11 inch 4th Gen",
			"iPad14,5":"iPad Pro 12.9 inch 6th Gen",
			"iPad14,6":"iPad Pro 12.9 inch 6th Gen",
			"Watch1,1":"Apple Watch 38mm case",
			"Watch1,2":"Apple Watch 42mm case",
			"Watch2,6":"Apple Watch Series 1 38mm case",
			"Watch2,7":"Apple Watch Series 1 42mm case",
			"Watch2,3":"Apple Watch Series 2 38mm case",
			"Watch2,4":"Apple Watch Series 2 42mm case",
			"Watch3,1":"Apple Watch Series 3 38mm case (GPS+Cellular)",
			"Watch3,2":"Apple Watch Series 3 42mm case (GPS+Cellular)",
			"Watch3,3":"Apple Watch Series 3 38mm case (GPS)",
			"Watch3,4":"Apple Watch Series 3 42mm case (GPS)",
			"Watch4,1":"Apple Watch Series 4 40mm case (GPS)",
			"Watch4,2":"Apple Watch Series 4 44mm case (GPS)",
			"Watch4,3":"Apple Watch Series 4 40mm case (GPS+Cellular)",
			"Watch4,4":"Apple Watch Series 4 44mm case (GPS+Cellular)",
			"Watch5,1":"Apple Watch Series 5 40mm case (GPS)",
			"Watch5,2":"Apple Watch Series 5 44mm case (GPS)",
			"Watch5,3":"Apple Watch Series 5 40mm case (GPS+Cellular)",
			"Watch5,4":"Apple Watch Series 5 44mm case (GPS+Cellular)",
			"Watch5,9":"Apple Watch SE 40mm case (GPS)",
			"Watch5,10":"Apple Watch SE 44mm case (GPS)",
			"Watch5,11":"Apple Watch SE 40mm case (GPS+Cellular)",
			"Watch5,12":"Apple Watch SE 44mm case (GPS+Cellular)",
			"Watch6,1":"Apple Watch Series 6 40mm case (GPS)",
			"Watch6,2":"Apple Watch Series 6 44mm case (GPS)",
			"Watch6,3":"Apple Watch Series 6 40mm case (GPS+Cellular)",
			"Watch6,4":"Apple Watch Series 6 44mm case (GPS+Cellular)",
			"Watch6,6":"Apple Watch Series 7 41mm case (GPS)",
			"Watch6,7":"Apple Watch Series 7 45mm case (GPS)",
			"Watch6,8":"Apple Watch Series 7 41mm case (GPS+Cellular)",
			"Watch6,9":"Apple Watch Series 7 45mm case (GPS+Cellular)",
			"Watch6,10":"Apple Watch SE 40mm case (GPS)",
			"Watch6,11":"Apple Watch SE 44mm case (GPS)",
			"Watch6,12":"Apple Watch SE 40mm case (GPS+Cellular)",
			"Watch6,13":"Apple Watch SE 44mm case (GPS+Cellular)",
			"Watch6,14":"Apple Watch Series 8 41mm case (GPS)",
			"Watch6,15":"Apple Watch Series 8 45mm case (GPS)",
			"Watch6,16":"Apple Watch Series 8 41mm case (GPS+Cellular)",
			"Watch6,17":"Apple Watch Series 8 45mm case (GPS+Cellular)",
			"Watch6,18":"Apple Watch Ultra",
		]
		if let machine = machine {
			return machines[machine] ?? UIDevice.current.localizedModel
		} else {
			return UIDevice.current.localizedModel
		}
	}

	public var deviceSecure: Bool {
		return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
	}

	public var deviceTimeZone: String? {
		return DateStaticFormatters.CurrentJavaCompatibleTimeZoneOffset
	}

	public var pushServiceType: String {
		return Consts.APIValues.platformType
	}

    public var currentUserAgentString: String {
		var options = [MMUserAgent.DataOptions.None]
		if !(MobileMessaging.privacySettings.systemInfoSendingDisabled) {
			options.append(MMUserAgent.DataOptions.System)
		}
		if !(MobileMessaging.privacySettings.carrierInfoSendingDisabled) {
			options.append(MMUserAgent.DataOptions.Carrier)
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

			let result = "\(libraryName)/\(libraryVersion.appending(pluginVersion == nil ? "" : " \(pluginVersion!)"))(\(outputOSName);\(outputOSVersion);\(osArch);\(outputDeviceModel);\(deviceManufacturer);\(outputHostingAppName);\(outputHostingAppVersion);\(deviceNameS)"

			return result
		}

		func carrierDataString(allowed: Bool) -> String {
			let networkInfo = CTTelephonyNetworkInfo()
            let carrier = allowed ? networkInfo.serviceSubscriberCellularProviders?.first?.value : nil
			let mobileCarrierName = carrier?.carrierName ?? ""
			let mobileCountryCode = carrier?.mobileCountryCode ?? ""
			let mobileNetworkCode = carrier?.mobileNetworkCode ?? ""

			return ";\(mobileCarrierName);\(mobileNetworkCode);\(mobileCountryCode)"
		}

		return systemDataString(allowed: options.contains(MMUserAgent.DataOptions.System)) + carrierDataString(allowed: options.contains(MMUserAgent.DataOptions.Carrier)) + ")"
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
