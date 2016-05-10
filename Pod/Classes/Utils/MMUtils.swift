//
//  MMUtils.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//  
//

import Foundation
import CoreData
import MMAFNetworking

extension OperationQueue {
	class var newSerialQueue: OperationQueue {
		let newQ = OperationQueue()
		newQ.maxConcurrentOperationCount = 1
		return newQ
	}
}

class MMNetworkReachabilityManager {
	static let sharedInstance = MMNetworkReachabilityManager()
	private let manager: MM_AFNetworkReachabilityManager
	init() {
		manager = MM_AFNetworkReachabilityManager.sharedManager()
	}
	var localizedNetworkReachabilityStatusString: String {
		return manager.localizedNetworkReachabilityStatusString()
	}
	
	func startMonitoring() { manager.startMonitoring() }
	func stopMonitoring() { manager.stopMonitoring() }
	var reachable: Bool { return manager.reachable }
	
	func currentlyReachable() -> Bool {
		var zeroAddress = sockaddr_in()
		zeroAddress.sin_len = UInt8(sizeofValue(zeroAddress))
		zeroAddress.sin_family = sa_family_t(AF_INET)
		let rechability = withUnsafePointer(&zeroAddress) {
			SCNetworkReachabilityCreateWithAddress(nil, UnsafePointer($0))
		}
		var flags : SCNetworkReachabilityFlags = SCNetworkReachabilityFlags()
		if SCNetworkReachabilityGetFlags(rechability!, &flags) == false {
			return false
		}
		let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
		let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
		return (isReachable && !needsConnection)
	}
	func setReachabilityStatusChangeBlock(block: ((AFNetworkReachabilityStatus) -> Void)?) {
		manager.setReachabilityStatusChangeBlock(block)
	}
}

extension UIApplication {
	var isCurrentAppRegisteredForRemoteNotifications: Bool {
		return UIApplication.sharedApplication().isRegisteredForRemoteNotifications()
	}
	var isRemoteNotificationsEnabled: Bool {
		guard let notificationType = self.currentUserNotificationSettings()?.types else {
			return false
		}
		return notificationType != .None
	}
}

extension NSData {
    var toHexString: String {
        let tokenChars = UnsafePointer<CChar>(self.bytes)
        var tokenString = ""
        for i in 0..<self.length {
            tokenString += String(format: "%02.2hhx", arguments: [tokenChars[i]])
        }
        return tokenString
    }
}

extension String {
    
    func toHexademicalString() -> String? {
        if let data: NSData = self.dataUsingEncoding(NSUTF16StringEncoding) {
            return data.toHexString
        } else {
            return nil
        }
    }
    
    func fromHexademicalString() -> String? {
        if let data = self.dataFromHexadecimalString() {
            return String.init(data: data, encoding: NSUTF16StringEncoding)
        } else {
            return nil
        }
    }
    
    func dataFromHexadecimalString() -> NSData? {
        let trimmedString = self.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<> ")).stringByReplacingOccurrencesOfString(" ", withString: "")
        
        // make sure the cleaned up string consists solely of hex digits, and that we have even number of them
        
        let regex = try! NSRegularExpression(pattern: "^[0-9a-f]*$", options: .CaseInsensitive)
        
        let found = regex.firstMatchInString(trimmedString, options: [], range: NSMakeRange(0, trimmedString.characters.count))
        if found == nil || found?.range.location == NSNotFound || trimmedString.characters.count % 2 != 0 {
            return nil
        }
        
        // everything ok, so now let's build NSData
        
        let data = NSMutableData(capacity: trimmedString.characters.count / 2)
		
		var index = trimmedString.startIndex
		while index < trimmedString.endIndex {
            let byteString = trimmedString.substringWithRange(index ..< index.successor().successor())
            let num = UInt8(byteString.withCString { strtoul($0, nil, 16) })
            data?.appendBytes([num] as [UInt8], length: 1)
			index = index.successor().successor()
        }
        
        return data
    }
}

func += <Key, Value> (inout left: Dictionary<Key, Value>, right: Dictionary<Key, Value>?) {
	guard let right = right else {
		return
	}
	for (k, v) in right {
		left.updateValue(v, forKey: k)
	}
}

func + <Key, Value> (l: Dictionary<Key, Value>?, r: Dictionary<Key, Value>?) -> Dictionary<Key, Value>? {
	
	switch (l, r) {
	case (.None, .None):
		return nil
	case (.Some(let left), .None):
		return left
	case (.None, .Some(let right)):
		return right
	case (.Some(let left), .Some(let right)):
		var lMutable = left
		for (k, v) in right {
			lMutable[k] = v
		}
		return lMutable
	}
}
