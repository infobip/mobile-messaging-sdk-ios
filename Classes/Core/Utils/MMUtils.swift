//
//  MMUtils.swift
//  MobileMessaging
//
//  Created by Andrey K. on 17/02/16.
//
//

import Foundation
import CoreData
import CoreLocation
import SystemConfiguration
import UserNotifications

public typealias DictionaryRepresentation = [String: Any]

struct DateStaticFormatters {
	static var ContactsServiceDateFormatter: DateFormatter = {
		let result = DateFormatter()
		result.locale = Locale(identifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd"
		return result
	}()
	
	static var ISO8601SecondsFormatter: DateFormatter = {
		let result = DateFormatter()
		result.locale = Locale(identifier: "en_US_POSIX")
		result.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
		result.timeZone = TimeZone(secondsFromGMT: 0)
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

extension Dictionary where Key: ExpressibleByStringLiteral, Value: UserDataFoundationTypes {
	public var customUserDataValues: [Key: CustomUserDataValue]? {
		let result = self.reduce([Key: CustomUserDataValue](), { (result, tuple) -> [Key: CustomUserDataValue] in
			var r = result
			r[tuple.0] = CustomUserDataValue(withFoundationValue: tuple.1)
			return r
		})
		return result
	}
}

extension Dictionary where Key: ExpressibleByStringLiteral, Value: CustomUserDataValue {
	public var userDataFoundationTypes: [Key: UserDataFoundationTypes]? {
		let result = self.reduce([Key: UserDataFoundationTypes](), { (result, tuple) -> [Key: UserDataFoundationTypes] in
			var r = result
			r[tuple.0] = tuple.1.dataValue
			return r
		})
		return result
	}
}

extension Dictionary where Value: Hashable {
	var keyValuesHash: Int {
		return self.reduce("", {"\($0.0),\($0.1)"}).hash
	}
}

extension Dictionary where Key: ExpressibleByStringLiteral, Value: Any {
	var nilIfEmpty: [Key: Value]? {
		return self.isEmpty ? nil : self
	}
}


public extension Dictionary where Key: ExpressibleByStringLiteral, Value: Any {
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

class MMNetworkReachabilityManager: ReachabilityManagerProtocol {
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

extension Data {
	var mm_toHexString: String {
		return reduce("") {$0 + String(format: "%02x", $1)}
	}
}

extension String {
	
	static let mm_UUIDRegexPattern = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
	
	func mm_matches(toRegexPattern: String, options: NSRegularExpression.Options = []) -> Bool {
		if let regex = try? NSRegularExpression(pattern: toRegexPattern, options: options), let _ = regex.firstMatch(in: self, options: NSRegularExpression.MatchingOptions.withoutAnchoringBounds, range: NSRange(0..<self.characters.count)) {
			return true
		} else {
			return false
		}
	}
	
	var mm_isSdkGeneratedMessageId: Bool {
		return mm_isUUID
	}
	
	var mm_isUUID: Bool {
		return mm_matches(toRegexPattern: String.mm_UUIDRegexPattern, options: .caseInsensitive)
	}
	
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
	
	var mm_toHexademicalString: String? {
		if let data: Data = self.data(using: String.Encoding.utf16) {
			return data.mm_toHexString
		} else {
			return nil
		}
	}
	
	var mm_fromHexademicalString: String? {
		if let data = self.mm_dataFromHexadecimalString {
			return String.init(data: data, encoding: String.Encoding.utf16)
		} else {
			return nil
		}
	}
	
	var mm_dataFromHexadecimalString: Data? {
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
	
	var mm_urlSafeString: String {
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

func + <Key, Value> (l: Dictionary<Key, Value>?, r: Dictionary<Key, Value>) -> Dictionary<Key, Value> {
	switch (l, r) {
	case (.none, _):
		return r
	case (.some(let left), _):
		var lMutable = left
		for (k, v) in r {
			lMutable[k] = v
		}
		return lMutable
	}
}

func + <Element: Any>(l: Set<Element>?, r: Set<Element>?) -> Set<Element>? {
    switch (l, r) {
    case (.none, .none):
        return nil
    case (.some(let left), .none):
        return left
    case (.none, .some(let right)):
        return right
    case (.some(let left), .some(let right)):
        return left.union(right)
    }
}

func + <Element: Any>(l: [Element]?, r: [Element]?) -> [Element] {
	switch (l, r) {
	case (.none, .none):
		return [Element]()
	case (.some(let left), .none):
		return left
	case (.none, .some(let right)):
		return right
	case (.some(let left), .some(let right)):
		return left + right
	}
}

func ==(lhs : [AnyHashable : UserDataFoundationTypes], rhs: [AnyHashable : UserDataFoundationTypes]) -> Bool {
	return NSDictionary(dictionary: lhs).isEqual(to: rhs)
}

func !=(lhs : [AnyHashable : UserDataFoundationTypes], rhs: [AnyHashable : UserDataFoundationTypes]) -> Bool {
	return !NSDictionary(dictionary: lhs).isEqual(to: rhs)
}

func isIOS9() -> Bool {
	if #available(iOS 9.0, *) {
		return true
	} else {
		return false
	}
}

protocol DictionaryRepresentable {
	init?(dictRepresentation dict: DictionaryRepresentation)
	var dictionaryRepresentation: DictionaryRepresentation {get}
}

extension Date {
	var timestampDelta: UInt {
		return UInt(max(0, MobileMessaging.date.now.timeIntervalSinceReferenceDate - self.timeIntervalSinceReferenceDate))
	}
}

var isTestingProcessRunning: Bool {
	return ProcessInfo.processInfo.arguments.contains("-IsStartedToRunTests")
}

protocol MobileMessagingService {
	var uniqueIdentifier: String { get }
	var isRunning: Bool { get }
	func start(_ completion: ((Bool) -> Void)?)
	func stop(_ completion: ((Bool) -> Void)?)
	func syncWithServer(_ completion: ((NSError?) -> Void)?)
	
	/// A system data that is related to a particular subservice. For example for Geofencing service it is a key-value pair "geofencing: <bool>" that indicates whether the service is enabled or not
	var systemData: [String: AnyHashable]? { get }

	/// A subservice must implement this method in order to let MobileMessaging be aware of the subservice plugged in.
	func registerSelfAsSubservice(of mmContext: MobileMessaging)
	
	/// Called by message handling operation in order to fill the MessageManagedObject data by MobileMessaging subservices. Subservice must be in charge of fulfilling the message data to be stored on disk. You return `true` if message was changed by the method.
	func populateNewPersistedMessage(_ message: inout MessageManagedObject, originalMessage: MTMessage) -> Bool
	
	func handleNewMessage(_ message: MTMessage, completion: ((MessageHandlingResult) -> Void)?)
	func handleAnyMessage(_ message: MTMessage, completion: ((MessageHandlingResult) -> Void)?)

	func mobileMessagingWillStart(_ mmContext: MobileMessaging)
	func mobileMessagingDidStart(_ mmContext: MobileMessaging)
	
	func mobileMessagingWillStop(_ mmContext: MobileMessaging)
	func mobileMessagingDidStop(_ mmContext: MobileMessaging)
	
	func pushRegistrationStatusDidChange(_ mmContext: MobileMessaging)
}

extension MobileMessagingService {
	var systemData: [String: AnyHashable]? { return nil }
	
	func registerSelfAsSubservice(of mmContext: MobileMessaging) { mmContext.registerSubservice(self) }
	
	func handleNewMessage(_ message: MTMessage, completion: ((MessageHandlingResult) -> Void)?) { completion?(.noData) }
	func handleAnyMessage(_ message: MTMessage, completion: ((MessageHandlingResult) -> Void)?) { completion?(.noData) }
	
	func mobileMessagingWillStart(_ mmContext: MobileMessaging) {}
	func mobileMessagingDidStart(_ mmContext: MobileMessaging) {}
	
	func mobileMessagingWillStop(_ mmContext: MobileMessaging) {}
	func mobileMessagingDidStop(_ mmContext: MobileMessaging) {}
	
	func pushRegistrationStatusDidChange(_ mmContext: MobileMessaging) {}
	
	func populateNewPersistedMessage(_ message: inout MessageManagedObject, originalMessage: MTMessage) -> Bool { return false }
}

extension Sequence {
	func forEachAsync(_ work: @escaping (Self.Iterator.Element) -> Void, completion: @escaping () -> Void) {
		let loopGroup = DispatchGroup()
		self.forEach { (el) in
			loopGroup.enter()
			
			work(el)
			
			loopGroup.leave()
		}
		
		loopGroup.notify(queue: DispatchQueue.global(qos: .default), execute: {
			completion()
		})
	}
}

public extension UIDevice {
	public func SYSTEM_VERSION_LESS_THAN(_ version: String) -> Bool {
		return self.systemVersion.compare(version, options: .numeric) == .orderedAscending
	}
	
	public var IS_IOS_BEFORE_10: Bool { return SYSTEM_VERSION_LESS_THAN("10.0") }
}

class MMDate {
	var now: Date {
		return Date()
	}
	
	func timeInterval(sinceNow timeInterval: TimeInterval) -> Date {
		return Date(timeIntervalSinceNow: timeInterval)
	}
	
	func timeInterval(since1970 timeInterval: TimeInterval) -> Date {
		return Date(timeIntervalSince1970: timeInterval)
	}
	
	func timeInterval(sinceReferenceDate timeInterval: TimeInterval) -> Date {
		return Date(timeIntervalSinceReferenceDate: timeInterval)
	}
	
	func timeInterval(_ timeInterval: TimeInterval, since date: Date) -> Date {
		return Date(timeInterval: timeInterval, since: date)
	}
}

protocol UserNotificationCenterStorage {
	func getDeliveredMessages(completionHandler: @escaping ([MTMessage]) -> Swift.Void)
}

class DefaultUserNotificationCenterStorage : UserNotificationCenterStorage {
	func getDeliveredMessages(completionHandler: @escaping ([MTMessage]) -> Swift.Void) {
		if #available(iOS 10.0, *) {
			UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
				let messages = notifications.flatMap({ return MTMessage(payload: $0.request.content.userInfo) })
				completionHandler(messages)
			}
		} else {
			return completionHandler([])
		}
	}
}

protocol MMApplication {
	var applicationIconBadgeNumber: Int { get set }
	var applicationState: UIApplicationState { get }
	var isRegisteredForRemoteNotifications: Bool { get }
	func unregisterForRemoteNotifications()
	func registerForRemoteNotifications()
	func presentLocalNotificationNow(_ notification: UILocalNotification)
	func registerUserNotificationSettings(_ notificationSettings: UIUserNotificationSettings)
	var currentUserNotificationSettings: UIUserNotificationSettings? { get }
}

extension MMApplication {
	var isInForegroundState: Bool {
		return applicationState != .background
	}
}

func applicationCodeChanged(storage: MMCoreDataStorage, newApplicationCode: String) -> Bool {
	let dataProvider = CoreDataProvider(storage: storage)
	let currentApplicationCode = dataProvider.getValueForKey("applicationCode") as? String
	return currentApplicationCode != nil && currentApplicationCode != newApplicationCode
}

extension String {
	static func localizedUserNotificationStringOrFallback(key: String?, args: [String]?, fallback: String?) -> String? {
		let ret: String?
		if let key = key {
			if #available(iOS 10.0, *) {
				if let args = args {
					ret = NSString.localizedUserNotificationString(forKey: key, arguments: args)
				} else {
					ret = NSLocalizedString(key, comment: "") as String
				}
			} else {
				let localizedString = NSLocalizedString(key, comment: "")
				if let args = args {
					ret = String(format: localizedString as String, arguments: args)
				} else {
					ret = localizedString as String
				}
			}
		} else {
			ret = fallback
		}
		return ret
	}
}
