//
//  MMUtils.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//  
//

import Foundation
import CoreData

struct NSDateStaticFormatters {
	static var ContactsServiceDateFormatter: DateFormatter = {
		let result = DateFormatter()
		result.locale = Locale(identifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd"
		return result
	}()
	static var ISO8601Formatter: DateFormatter = {
		let result = DateFormatter()
		result.locale = Locale(identifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
		return result
	}()
	static var CoreDataDateFormatter: DateFormatter = {
		let result = DateFormatter()
		result.locale = Locale(identifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
		return result
	}()
	static var timeFormatter: DateFormatter = {
		let result = DateFormatter()
		result.dateStyle = DateFormatter.Style.none
		result.timeStyle = DateFormatter.Style.short
		return result
	}()
}

public extension Dictionary where Key: NSObject, Value: AnyObject {
	public var mm_apsAlertBody: String? {
		return (self as NSDictionary).mm_apsAlertBody
	}
	
	public var mm_messageId: String? {
		return (self as NSDictionary).mm_messageId
	}
}

public extension NSDictionary {
	public var mm_apsAlertBody: String? {
		var messageDict: NSDictionary
		if let aps = self["aps"] as? NSDictionary {
			messageDict = aps
		} else {
			messageDict = self
		}
		
		if let alert = messageDict["alert"] as? String {
			return alert
		} else if let alert = messageDict["alert"] as? NSDictionary, let body = alert["body"] as? String {
			return body
		} else {
			return nil
		}
	}
	
	public var mm_messageId: String? {
		return self["messageId"] as? String
	}
}

extension NotificationCenter {
	class func mm_postNotificationFromMainThread(name: String, userInfo: [AnyHashable: Any]?) {
		MMQueue.Main.queue.executeAsync {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: name), object: self, userInfo: userInfo)
		}
	}
}

extension OperationQueue {
	class var mm_newSerialQueue: OperationQueue {
		let newQ = OperationQueue()
		newQ.maxConcurrentOperationCount = 1
		return newQ
	}
}

class MMNetworkReachabilityManager {
	static let sharedInstance = MMNetworkReachabilityManager()
	private let manager: MM_AFNetworkReachabilityManager
	init() {
		manager = MM_AFNetworkReachabilityManager.shared()
	}
	var localizedNetworkReachabilityStatusString: String {
		return manager.localizedNetworkReachabilityStatusString()
	}
	
	func startMonitoring() { manager.startMonitoring() }
	func stopMonitoring() { manager.stopMonitoring() }
	var reachable: Bool { return manager.isReachable }
	
	func currentlyReachable() -> Bool {
        var zeroAddress = sockaddr_in()
		zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
		zeroAddress.sin_family = sa_family_t(AF_INET)
		
		guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
			$0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
				SCNetworkReachabilityCreateWithAddress(nil, $0)
			}
		}) else {
			return false
		}
		
		var flags: SCNetworkReachabilityFlags = []
		if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
			return false
		}
		
		let isReachable = flags.contains(.reachable)
		let needsConnection = flags.contains(.connectionRequired)
		
		return (isReachable && !needsConnection)
	}
	func setReachabilityStatusChangeBlock(block: ((AFNetworkReachabilityStatus) -> Void)?) {
		manager.setReachabilityStatusChange(block)
	}
}

extension UIApplication {
	var mm_isCurrentAppRegisteredForRemoteNotifications: Bool {
		return UIApplication.shared.isRegisteredForRemoteNotifications
	}
}

extension Data {
    var mm_toHexString: String {
		return reduce("") {$0 + String(format: "%02x", $1)}
    }
}

extension String {
	func mm_breakWithMaxLength(maxLenght: Int) -> String {
		var result: String = self
		let currentLen = self.characters.count
		let doPutDots = maxLenght > 3
		if currentLen > maxLenght {
			if let index = self.index(self.startIndex, offsetBy: maxLenght - (doPutDots ? 3 : 0), limitedBy: self.endIndex) {
				result = self.substring(to: index) + (doPutDots ? "..." : "")
			}
		}
		return result
	}
	
    func mm_toHexademicalString() -> String? {
        if let data: Data = self.data(using: String.Encoding.utf16) {
            return data.mm_toHexString
        } else {
            return nil
        }
    }
    
    func mm_fromHexademicalString() -> String? {
        if let data = self.mm_dataFromHexadecimalString() {
            return String.init(data: data, encoding: String.Encoding.utf16)
        } else {
            return nil
        }
    }
    
    func mm_dataFromHexadecimalString() -> Data? {
		let trimmedString = self.trimmingCharacters(in: CharacterSet.init(charactersIn:"<> ")).replacingOccurrences(of: " ", with: "")
        
        // make sure the cleaned up string consists solely of hex digits, and that we have even number of them
        
        let regex = try! NSRegularExpression(pattern: "^[0-9a-f]*$", options: .caseInsensitive)
        
        let found = regex.firstMatch(in: trimmedString, options: [], range: NSMakeRange(0, trimmedString.characters.count))
        if found == nil || found?.range.location == NSNotFound || trimmedString.characters.count % 2 != 0 {
            return nil
        }
        
        // everything ok, so now let's build NSData
		var data = Data()
		
		var index = trimmedString.startIndex
		
		while index < trimmedString.endIndex {
			let range:Range<Index> = index..<trimmedString.index(index, offsetBy: 2)
			let byteString = trimmedString.substring(with: range)
            let num = UInt8(byteString.withCString { strtoul($0, nil, 16) })
            data.append([num] as [UInt8], count: 1)
			index = trimmedString.index(index, offsetBy: 2)
        }
		
        return data
    }

	func mm_escapeString() -> String {
		let raw: String = self
		var urlFragmentAllowed = CharacterSet.urlFragmentAllowed
		urlFragmentAllowed.remove(charactersIn: "!*'();:@&=+$,/?%#[]")
		var result = String()
		if let str = raw.addingPercentEncoding(withAllowedCharacters: urlFragmentAllowed) {
			result = str
		}
		return result
	}
}

func += <Key, Value> (left: inout Dictionary<Key, Value>, right: Dictionary<Key, Value>?) {
	guard let right = right else {
		return
	}
	for (k, v) in right {
		left.updateValue(v, forKey: k)
	}
}

func + <Key, Value> (l: Dictionary<Key, Value>?, r: Dictionary<Key, Value>?) -> Dictionary<Key, Value>? {
	
	switch (l, r) {
	case (.none, .none):
		return nil
	case (.some(let left), .none):
		return left
	case (.none, .some(let right)):
		return right
	case (.some(let left), .some(let right)):
		var lMutable = left
		for (k, v) in right {
			lMutable[k] = v
		}
		return lMutable
	}
}

func ==(lhs : [AnyHashable : UserDataSupportedTypes], rhs: [AnyHashable : UserDataSupportedTypes]) -> Bool {
	return NSDictionary(dictionary: lhs).isEqual(to: rhs)
}

func !=(lhs : [AnyHashable : UserDataSupportedTypes], rhs: [AnyHashable : UserDataSupportedTypes]) -> Bool {
	return !NSDictionary(dictionary: lhs).isEqual(to: rhs)
}

func isIOS9() -> Bool {
	if #available(iOS 9.0, *) {
		return true
	} else {
		return false
	}
}
