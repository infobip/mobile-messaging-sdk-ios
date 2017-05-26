//
//  MMUserAgent.swift
//
//  Created by Andrey K. on 08/07/16.
//

import Foundation
import CoreTelephony

func ==(lhs: MMSystemData, rhs: MMSystemData) -> Bool {
	return lhs.hashValue == rhs.hashValue
}
struct MMSystemData: Hashable {
	let SDKVersion, OSVer, deviceManufacturer, deviceModel, appVer: String
	let notificationsEnabled: Bool
	var dictionaryRepresentation: [String: AnyHashable] {

		var result : [String: AnyHashable] = [
												SystemDataKeys.geofencingServiceEnabled: false,
												SystemDataKeys.notificationsEnabled: notificationsEnabled,
												SystemDataKeys.sdkVersion: SDKVersion
										     ]
		if (!MobileMessaging.privacySettings.systemInfoSendingDisabled) {
			result[SystemDataKeys.osVer] = OSVer
			result[SystemDataKeys.deviceManufacturer] = deviceManufacturer
			result[SystemDataKeys.deviceModel] = deviceModel
			result[SystemDataKeys.appVer] = appVer
		}
		return (result as [String: AnyHashable]).mm_applySubservicesSystemData()
	}
	
	var hashValue: Int {
		//we care only about values!
		return dictionaryRepresentation.keyValuesHash
	}
}

public class MMUserAgent: NSObject {
	public var cordovaPluginVersion: String?
	
	struct DataOptions : OptionSet {
		let rawValue: Int
		init(rawValue: Int = 0) { self.rawValue = rawValue }
		static let None = DataOptions(rawValue: 0)
		static let System = DataOptions(rawValue: 1 << 0)
		static let Carrier = DataOptions(rawValue: 1 << 1)
	}
	
	var systemData: MMSystemData {
		return MMSystemData(SDKVersion: libraryVersion.appending(cordovaPluginVersion == nil ? "" : " (cordova \(cordovaPluginVersion!))"), OSVer: osVersion, deviceManufacturer: deviceManufacturer, deviceModel: deviceName, appVer: hostingAppVersion, notificationsEnabled: notificationsEnabled)
	}
	
	public var notificationsEnabled: Bool {
		guard let settings = MobileMessaging.sharedInstance?.application.currentUserNotificationSettings else {
			return false
		}
		return !settings.types.isEmpty
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
	
	public var osVersion: String {
		return UIDevice.current.systemVersion
	}
	
	public var osName: String {
		return UIDevice.current.systemName
	}
	
	public var libraryVersion: String {
		return (Bundle(identifier:"org.cocoapods.MobileMessaging")?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? mobileMessagingVersion)
	}
	
	public var libraryName: String {
		return Bundle(identifier:"org.cocoapods.MobileMessaging")?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "MobileMessaging"
	}
	
	public var hostingAppVersion: String {
		return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
	}
	
	public var hostingAppName: String {
		return Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
	}
	
	public var deviceManufacturer: String {
		return "Apple"
	}

	public var deviceName : String {
		let name = UnsafeMutablePointer<utsname>.allocate(capacity: 1)
		defer {
			name.deallocate(capacity: 1)
		}
		uname(name)
		let machine = withUnsafePointer(to: &name.pointee.machine, { (ptr) -> String? in
			let int8Ptr = unsafeBitCast(ptr, to: UnsafePointer<Int8>.self)
			return String(validatingUTF8: int8Ptr)
		})
		
		let machines = [
			"iPod1,1":"iPod Touch",
			"iPod2,1":"iPod Touch 2",
			"iPod3,1":"iPod Touch 3",
			"iPod4,1":"iPod Touch 4",
			"iPod5,1":"iPod Touch 5",
			"iPod7,1":"iPod Touch 6",
			
			"iPhone3,1":"iPhone 4 (GSM)",
			"iPhone3,2":"iPhone 4",
			"iPhone3,3":"iPhone 4 (CDMA/Verizon/Sprint)",
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
			"iPad5,2":"iPad Mini 4 (Cellular)",
			"iPad5,3":"iPad Air 2 (WiFi)",
			"iPad5,4":"iPad Air 2 (Cellular)",
			
			"iPad6,3":"iPad Pro 12.9\" (WiFi)",
			"iPad6,4":"iPad Pro 12.9\" (Cellular)",
			"iPad6,7":"iPad Pro 9.7\" (WiFi)",
			"iPad6,8":"iPad Pro 9.7\" (Cellular)",
			
			"i386":"32-bit Simulator",
			"x86_64":"64-bit Simulator"
		]
		if let machine = machine {
			return machines[machine] ?? UIDevice.current.localizedModel
		} else {
			return UIDevice.current.localizedModel
		}
	}
	
	func userAgentString(withOptions options: [DataOptions]) -> String {
		func systemDataString(allowed: Bool) -> String {
			let outputOSName = allowed ? osName : ""
			let outputOSVersion = allowed ? osVersion : ""
			let outputDeviceModel = allowed ? deviceName : ""
			let osArch = ""
			let deviceManufacturer = ""
			let outputHostingAppName = allowed ? hostingAppName : ""
			let outputHostingAppVersion = allowed ? hostingAppVersion : ""
			
			let result = "\(libraryName)/\(libraryVersion.appending(cordovaPluginVersion == nil ? "" : "-cordova-\(cordovaPluginVersion!)"))(\(outputOSName);\(outputOSVersion);\(osArch);\(outputDeviceModel);\(deviceManufacturer);\(outputHostingAppName);\(outputHostingAppVersion)"
			
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
