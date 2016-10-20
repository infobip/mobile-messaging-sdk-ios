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

struct NSDateStaticFormatters {
	static var ContactsServiceDateFormatter: NSDateFormatter = {
		let result = NSDateFormatter()
		result.locale = NSLocale(localeIdentifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd"
		return result
	}()
	static var ISO8601SecondsFormatter: NSDateFormatter = {
		let result = NSDateFormatter()
		result.locale = NSLocale(localeIdentifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
		return result
	}()
	static var CoreDataDateFormatter: NSDateFormatter = {
		let result = NSDateFormatter()
		result.locale = NSLocale(localeIdentifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
		return result
	}()
	static var timeFormatter: NSDateFormatter = {
		let result = NSDateFormatter()
		result.dateStyle = NSDateFormatterStyle.NoStyle
		result.timeStyle = NSDateFormatterStyle.ShortStyle
		return result
	}()
}

extension Dictionary where Key: StringLiteralConvertible, Value: UserDataFoundationTypes {
	public var customUserDataValues: [Key: CustomUserDataValue]? {
		let result = self.reduce([Key: CustomUserDataValue](), combine: { (result, tuple) -> [Key: CustomUserDataValue] in
			var r = result
			r[tuple.0] = CustomUserDataValue(withFoundationValue: tuple.1)
			return r
		})
		return result
	}
}

extension Dictionary where Key: StringLiteralConvertible, Value: CustomUserDataValue {
	public var userDataFoundationTypes: [Key: UserDataFoundationTypes]? {
		let result = self.reduce([Key: UserDataFoundationTypes](), combine: { (result, tuple) -> [Key: UserDataFoundationTypes] in
			var r = result
			r[tuple.0] = tuple.1.dataValue
			return r
		})
		return result
	}
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

extension NSNotificationCenter {
	class func mm_postNotificationFromMainThread(name: String, userInfo: [NSObject: AnyObject]?) {
		MMQueue.Main.queue.executeAsync {
			NSNotificationCenter.defaultCenter().postNotificationName(name, object: self, userInfo: userInfo)
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
	var mm_isCurrentAppRegisteredForRemoteNotifications: Bool {
		return UIApplication.sharedApplication().isRegisteredForRemoteNotifications()
	}
}

extension NSData {
    var mm_toHexString: String {
        let tokenChars = UnsafePointer<CChar>(self.bytes)
        var tokenString = ""
        for i in 0..<self.length {
            tokenString += String(format: "%02.2hhx", arguments: [tokenChars[i]])
        }
        return tokenString
    }
}

extension String {
	func mm_breakWithMaxLength(maxLenght: Int) -> String {
		var result: String = self
		let currentLen = self.characters.count
		let doPutDots = maxLenght > 3
		if currentLen > maxLenght {
			result = self.substringToIndex(self.startIndex.advancedBy(maxLenght - (doPutDots ? 3 : 0), limit: self.endIndex)) + (doPutDots ? "..." : "")
		}
		return result
	}
	
    func mm_toHexademicalString() -> String? {
        if let data: NSData = self.dataUsingEncoding(NSUTF16StringEncoding) {
            return data.mm_toHexString
        } else {
            return nil
        }
    }
    
    func mm_fromHexademicalString() -> String? {
        if let data = self.mm_dataFromHexadecimalString() {
            return String.init(data: data, encoding: NSUTF16StringEncoding)
        } else {
            return nil
        }
    }
    
    func mm_dataFromHexadecimalString() -> NSData? {
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
	
	func mm_escapeString() -> String {
		let raw: NSString = self
		let str = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, raw, nil, "!*'();:@&=+$,/?%#[]", CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding))
		return String(str)
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

func + <Key, Value> (l: Dictionary<Key, Value>, r: Dictionary<Key, Value>?) -> Dictionary<Key, Value> {
	
	switch (r) {
	case (.None):
		return l
	case (.Some(let right)):
		var lMutable = l
		for (k, v) in right {
			lMutable[k] = v
		}
		return lMutable
	}
}


func isIOS9() -> Bool {
	if #available(iOS 9.0, *) {
		return true
	} else {
		return false
	}
}

protocol DictionaryRepresentable {
	init?(dictRepresentation dict: [String: AnyObject])
	var dictionaryRepresentation: [String: AnyObject] {get}
}