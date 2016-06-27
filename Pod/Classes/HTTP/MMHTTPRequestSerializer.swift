//
//  MMHTTPRequestSerializer.swift
//  MobileMessaging
//
//  Created by okoroleva on 07.03.16.
//  

import MMAFNetworking
import CoreTelephony

final class MMHTTPRequestSerializer : MM_AFHTTPRequestSerializer {
	private var applicationCode: String
    private var jsonBody: [String: AnyObject]?
	private var headers: [String: String]?
    
    init(applicationCode: String, jsonBody: [String: AnyObject]?, headers: [String: String]?) {
		self.applicationCode = applicationCode
        self.jsonBody = jsonBody
		self.headers = headers
		super.init()
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
    override var HTTPMethodsEncodingParametersInURI : Set<String> {
        get {
            var params = super.HTTPMethodsEncodingParametersInURI
            params.insert("POST")
            return params
        }
        set {}
	}
	
	func applyHeaders(inout request: NSMutableURLRequest) {
		if let headers = headers {
			for (header, value) in headers {
				request.addValue(value, forHTTPHeaderField: header)
			}
		}
		request.addValue("App \(applicationCode)", forHTTPHeaderField: "Authorization")
		request.addValue(MMUserAgentData.currentUserAgent, forHTTPHeaderField: "User-Agent")
		if NSProcessInfo.processInfo().arguments.contains("-UseIAMMocks") {
			request.addValue("iam-mock", forHTTPHeaderField: "Accept-Features")
		}
	}
	
    override func requestWithMethod(method: String, URLString: String, parameters: AnyObject?, error: NSErrorPointer) -> NSMutableURLRequest {
        var request = NSMutableURLRequest()
		request.timeoutInterval = 20
        request.HTTPMethod = method
		request.URL = URL(withQueryParameters: parameters, url: URLString)
		applyHeaders(&request)
		
        if let jsonBody = jsonBody where method == "POST" {
            var data : NSData?
            do {
                data = try NSJSONSerialization.dataWithJSONObject(jsonBody, options: [])
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("application/json", forHTTPHeaderField: "Accept")
                request.HTTPBody = data
            } catch let error as NSError {
                MMLogError("RequestSerializer can't serialize json body: \(jsonBody) with error: \(error)")
            }
        }
        
        return request;
    }
	
	func URL(withQueryParameters parameters: AnyObject?, url: String) -> NSURL? {
		var completeURLString = url
		if let dictParams = parameters as? [String : AnyObject] {
			completeURLString += "?" + MMHTTPRequestSerializer.queryFromParameters(dictParams);
		}
		return NSURL(string: completeURLString)
	}
	
	class func queryFromParameters(parameters: [String: AnyObject]) -> String {
		var escapedPairs = [String]()
		for (key, value) in parameters {
			switch value {
			case let _value as String :
				escapedPairs.append("\(key.mm_escapeString())=\(_value.mm_escapeString())")
			case (let _values as [String]) :
				for arrayValue in _values {
					escapedPairs.append("\(key.mm_escapeString())=\(arrayValue.mm_escapeString())")
				}
			default:
				escapedPairs.append("\(key.mm_escapeString())=\(String(value).mm_escapeString())")
			}
		}
		return escapedPairs.joinWithSeparator("&")
	}
}

final class MMUserAgentData {
	
	struct DataOptions : OptionSetType {
		let rawValue: Int
		init(rawValue: Int = 0) { self.rawValue = rawValue }
		static let None = DataOptions(rawValue: 0)
		static let System = DataOptions(rawValue: 1 << 0)
		static let Carrier = DataOptions(rawValue: 1 << 1)
	}

	class func value(options: [DataOptions]) -> String {
		func systemValue(enabled: Bool) -> String {
			let libraryName = sharedInstance.libraryName
			let libraryVersion = sharedInstance.libraryVersion
			let osName = enabled ? sharedInstance.osName : ""
			let osVersion = enabled ? sharedInstance.osVersion : ""
			let deviceModel = enabled ? sharedInstance.deviceName : ""
			let osArch = ""
			let deviceManufacturer = ""
			let hostingAppName = enabled ? sharedInstance.hostingAppName : ""
			let hostingAppVersion = enabled ? sharedInstance.hostingAppVersion : ""
			let currCarrierName = ""
			let currMNC = ""
			let currMCC = ""
			
			let result = "\(libraryName)/\(libraryVersion)(\(osName);\(osVersion);\(osArch);\(deviceModel);\(deviceManufacturer);\(hostingAppName);\(hostingAppVersion);\(currCarrierName);\(currMNC);\(currMCC)"
			
			return result
		}
		
		func carrierValue(enabled: Bool) -> String {
			let networkInfo = CTTelephonyNetworkInfo()
			let carrier = enabled ? networkInfo.subscriberCellularProvider : nil
			
			let mobileCarrierName = carrier?.carrierName ?? ""
			let mobileCountryCode = carrier?.mobileCountryCode ?? ""
			let mobileNetworkCode = carrier?.mobileNetworkCode ?? ""
			
			return ";\(mobileCarrierName);\(mobileNetworkCode);\(mobileCountryCode))"
		}
		
		return systemValue(options.contains(self.DataOptions.System)) +
			   carrierValue(options.contains(self.DataOptions.Carrier))
	}
	
	class var currentUserAgent: String {
		var options = [MMUserAgentData.DataOptions.None]
		if MobileMessaging.shouldSendSystemInfo {
			options.append(MMUserAgentData.DataOptions.System)
		}
		
		if MobileMessaging.shouldSendCarrierInfo {
			options.append(MMUserAgentData.DataOptions.Carrier)
		}
		return MMUserAgentData.value(options)
	}
	
	private static let sharedInstance = MMUserAgentData()
    
    let osVersion : String = UIDevice.currentDevice().systemVersion
    let osName : String = UIDevice.currentDevice().systemName
    
    let libraryVersion: String = {
		return NSBundle(identifier:"org.cocoapods.MobileMessaging")?.objectForInfoDictionaryKey("CFBundleShortVersionString") as? String ?? libVersion
    }()
    
    let libraryName: String = {
		return NSBundle(identifier:"org.cocoapods.MobileMessaging")?.objectForInfoDictionaryKey("CFBundleName") as? String ?? "MobileMessaging"
    }()
    
    let hostingAppVersion: String = {
        return NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }()
	
	let hostingAppName: String = {
		return NSBundle.mainBundle().infoDictionary?["CFBundleName"] as? String ?? ""
	}()
	
	let deviceName : String = {
		let name = UnsafeMutablePointer<utsname>.alloc(1)
		defer {
			name.dealloc(1)
		}
		uname(name)
		let machine = withUnsafePointer(&name.memory.machine, { (ptr) -> String? in
			let int8Ptr = unsafeBitCast(ptr, UnsafePointer<Int8>.self)
			return String.fromCString(int8Ptr)
		})
		
		let machines = [
			"iPod5,1":"iPod Touch 5",
			"iPod7,1":"iPod Touch 6",
			"iPhone3,1":"iPhone 4",
			"iPhone3,2":"iPhone 4",
			"iPhone3,3":"iPhone 4",
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
			"iPad2,1":"iPad 2 (WiFi)",
			"iPad2,2":"iPad 2 (GSM)",
			"iPad2,3":"iPad 2 (CDMA)",
			"iPad2,4":"iPad 2 (WiFi Rev A)",
			"iPad3,1":"iPad 3 (WiFi)",
			"iPad3,3":"iPad 3",
			"iPad3,2":"iPad 3",
			"iPad3,4":"iPad 4 (WiFi)",
			"iPad3,5":"iPad 4 (GSM)",
			"iPad3,6":"iPad 4 (GSM+CDMA)",
			"iPad4,1":"iPad Air (WiFi)",
			"iPad4,2":"iPad Air (GSM)",
			"iPad4,3":"iPad Air (GSM+CDMA)",
			"iPad5,3":"iPad Air 2 (WiFi)",
			"iPad5,4":"iPad Air 2 (GSM+CDMA)",
			"iPad2,5":"iPad Mini (WiFi)",
			"iPad2,6":"iPad Mini (GSM)",
			"iPad2,7":"iPad Mini (GSM+CDMA)",
			"iPad4,4":"iPad Mini 2 (WiFi)",
			"iPad4,5":"iPad Mini 2 (GSM)",
			"iPad4,6":"iPad Mini 2 (GSM+CDMA)",
			"iPad4,7":"iPad Mini 3 (WiFi)",
			"iPad4,8":"iPad Mini 3 (GSM)",
			"iPad4,9":"iPad Mini 3 (GSM+CDMA)",
			"iPad5,2":"iPad Mini 4",
			"iPad5,1":"iPad Mini 4",
			"iPad6,3":"iPad Pro",
			"iPad6,4":"iPad Pro",
			"iPad6,7":"iPad Pro",
			"iPad6,8":"iPad Pro",
			"i386":"Simulator",
			"x86_64":"Simulator"
		]
		if let machine = machine {
			return machines[machine] ?? UIDevice.currentDevice().localizedModel
		} else {
			return UIDevice.currentDevice().localizedModel
		}
	}()
	
}
