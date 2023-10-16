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

extension MMStringKeyPayload {
    var mm_internalData: MMStringKeyPayload? {
        return self[Consts.APNSPayloadKeys.internalData] as? MMStringKeyPayload
    }
    var mm_inbox: MMStringKeyPayload? {
        return self.mm_internalData?[Consts.InternalDataKeys.inbox] as? MMStringKeyPayload
    }
}


func arrayToSet<T>(arr: [T]?) -> Set<T>? {
    return arr != nil ? Set<T>(arr!) : nil
}

func deltaDict(_ current: [String: Any], _ dirty: [String: Any]) -> [String: Any]? {
    var ret:[String: Any] = [:]
    dirty.keys.forEach { (k) in
        let currentV = current[k] as Any
        let dirtyV = dirty[k] as Any
        if checkIfAnyIsNil(dirtyV) {
            if checkIfAnyIsNil(currentV) {
                
            } else {
                ret[k] = NSNull()
            }
        } else {
            if (currentV is [String : Any] && dirtyV is [String : Any]) {
                let currentDict = currentV as! [String : Any]
                let dirtyDict = dirtyV as! [String : Any]
                if currentDict.isEmpty && dirtyDict.isEmpty {
                    ret[k] = nil
                } else {
                    ret[k] = deltaDict(currentDict, dirtyDict)
                }
            } else {
                if currentV is AnyHashable && dirtyV is AnyHashable {
                    if (currentV as! AnyHashable) != (dirtyV as! AnyHashable){
                        ret[k] = dirtyV
                    }
                } else {
                    if (checkIfAnyIsNil(currentV)) {
                        ret[k] = dirtyV
                    } else {
                        ret[k] = NSNull()
                    }
                }
            }
        }
    }
    return ret.isEmpty ? (!current.isEmpty && !dirty.isEmpty ? nil : ret) : ret
}

func isOptional(_ instance: Any) -> Bool {
    let mirror = Mirror(reflecting: instance)
    let style = mirror.displayStyle
    return style == .optional
}

func checkIfAnyIsNil(_ v: Any) -> Bool {
    if (isOptional(v)) {
        switch v {
        case Optional<Any>.none:
            return true
        case Optional<Any>.some(let v):
            return checkIfAnyIsNil(v)
        default:
            return false
        }
    } else {
        return false
    }
    
}


extension Dictionary where Key: ExpressibleByStringLiteral, Value: Any {
    var noNulls: [Key: Value] {
        return self.filter {
            let val = $0.1 as Any
            if case Optional<Any>.none = val {
                return false
            } else {
                return true
            }
        }
    }
}

public extension MobileMessaging {
    class var currentInstallation: MMInstallation? {
        return MobileMessaging.getInstallation()
    }
    class var currentUser: MMUser? {
        return MobileMessaging.getUser()
    }
}

func contactsServiceDateEqual(_ l: Date?, _ r: Date?) -> Bool {
    switch (l, r) {
    case (.none, .none):
        return true
    case (.some, .none):
        return false
    case (.none, .some):
        return false
    case (.some(let left), .some(let right)):
        return DateStaticFormatters.ContactsServiceDateFormatter.string(from: left) == DateStaticFormatters.ContactsServiceDateFormatter.string(from: right)
    }
}

public struct DateStaticFormatters {
    /**
     Desired format is GMT+03:00 and a special case for Greenwich Mean Time: GMT+00:00
     */
    static var CurrentJavaCompatibleTimeZoneOffset: String {
        var gmt = DateStaticFormatters.TimeZoneOffsetFormatter.string(from: MobileMessaging.date.now)
        if gmt == "GMT" {
            gmt = gmt + "+00:00"
        }
        return gmt
    }
    /**
     Desired format is GMT+03:00, not GMT+3
     */
    static var TimeZoneOffsetFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "ZZZZ"
        dateFormatter.timeZone = MobileMessaging.timeZone
        return dateFormatter
    }()
    static var LoggerDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
        return dateFormatter
    }()
    static var ContactsServiceDateFormatter: DateFormatter = {
        let result = DateFormatter()
        result.locale = Locale(identifier: "en_US_POSIX")
        result.dateFormat = "yyyy-MM-dd"
        result.timeZone = TimeZone(secondsFromGMT: 0)
        return result
    }()
    public static var ISO8601SecondsFormatter: DateFormatter = {
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

extension Dictionary where Key: ExpressibleByStringLiteral, Value: Hashable {
    var valuesStableHash: Int {
        return self.sorted { (kv1, kv2) -> Bool in
            if let key1 = kv1.key as? String, let key2 = kv2.key as? String {
                return key1.compare(key2) == .orderedAscending
            } else {
                return false
            }
        }.reduce("", {"\($0),\($1.1)"}).stableHash
    }
}

public extension String {
    var stableHash: Int {
        let unicodeScalars = self.unicodeScalars.map { $0.value }
        return unicodeScalars.reduce(5381) {
            ($0 << 5) &+ $0 &+ Int($1)
        }
    }

    func mm_components(withMaxLength length: Int) -> [String] {
         return stride(from: 0, to: self.count, by: length).map {
             let start = self.index(self.startIndex, offsetBy: $0)
             let end = self.index(start, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
             return String(self[start..<end])
         }
     }
}

extension Dictionary where Key: ExpressibleByStringLiteral, Value: Any {
    var nilIfEmpty: [Key: Value]? {
        return self.isEmpty ? nil : self
    }
}

extension Collection {
    var nilIfEmpty: Self? {
        return self.isEmpty ? nil : self
    }
}

extension Data {
    var mm_toHexString: String {
        return reduce("") {$0 + String(format: "%02x", $1)}
    }
}

extension String {
    var safeUrl: URL? {
        return URL(string: self)
    }
    
    func mm_matches(toRegexPattern: String, options: NSRegularExpression.Options = []) -> Bool {
        if let regex = try? NSRegularExpression(pattern: toRegexPattern, options: options), let _ = regex.firstMatch(in: self, options: NSRegularExpression.MatchingOptions.withoutAnchoringBounds, range: NSRange(0..<self.count)) {
            return true
        } else {
            return false
        }
    }
    
    var mm_isSdkGeneratedMessageId: Bool {
        return mm_isUUID
    }
    
    var mm_isUUID: Bool {
        return mm_matches(toRegexPattern: Consts.UUIDRegexPattern, options: .caseInsensitive)
    }
    
    func mm_breakWithMaxLength(maxLength: Int) -> String {
        var result: String = self
        let currentLen = self.count
        let doPutDots = maxLength > 3
        if currentLen > maxLength {
            if let index = self.index(self.startIndex, offsetBy: maxLength - (doPutDots ? 3 : 0), limitedBy: self.endIndex) {
                result = self[..<index] + (doPutDots ? "..." : "")
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
        
        let found = regex.firstMatch(in: trimmedString, options: [], range: NSMakeRange(0, trimmedString.count))
        if found == nil || found?.range.location == NSNotFound || trimmedString.count % 2 != 0 {
            return nil
        }
        
        // everything ok, so now let's build NSData
        var data = Data()
        
        var index = trimmedString.startIndex
        
        while index < trimmedString.endIndex {
            let range:Range<Index> = index..<trimmedString.index(index, offsetBy: 2)
            let byteString = trimmedString[range]
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

public func += <Key, Value> (left: inout Dictionary<Key, Value>, right: Dictionary<Key, Value>?) {
    guard let right = right else {
        return
    }
    for (k, v) in right {
        left.updateValue(v, forKey: k)
    }
}

public func + <Key, Value> (l: Dictionary<Key, Value>?, r: Dictionary<Key, Value>?) -> Dictionary<Key, Value>? {
    
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

public func + <Key, Value> (l: Dictionary<Key, Value>?, r: Dictionary<Key, Value>) -> Dictionary<Key, Value> {
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

public func + <Key, Value> (l: Dictionary<Key, Value>, r: Dictionary<Key, Value>) -> Dictionary<Key, Value> {
    var lMutable = l
    for (k, v) in r {
        lMutable[k] = v
    }
    return lMutable
}


public func + <Element: Any>(l: Set<Element>?, r: Set<Element>?) -> Set<Element>? {
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

public func + <Element: Any>(l: [Element]?, r: [Element]?) -> [Element] {
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

public func ==(lhs : [AnyHashable : MMAttributeType], rhs: [AnyHashable : MMAttributeType]) -> Bool {
    return NSDictionary(dictionary: lhs).isEqual(to: rhs)
}

public func ==(l : [String : MMAttributeType]?, r: [String : MMAttributeType]?) -> Bool {
    switch (l, r) {
    case (.none, .none):
        return true
    case (.some, .none):
        return false
    case (.none, .some):
        return false
    case (.some(let left), .some(let right)):
        return NSDictionary(dictionary: left).isEqual(to: right)
    }
}

public func !=(lhs : [AnyHashable : MMAttributeType], rhs: [AnyHashable : MMAttributeType]) -> Bool {
    return !NSDictionary(dictionary: lhs).isEqual(to: rhs)
}

public protocol DictionaryRepresentable {
    init?(dictRepresentation dict: DictionaryRepresentation)
    var dictionaryRepresentation: DictionaryRepresentation {get}
}

public extension Date {
    func mm_epochUnixTimestamp() -> Int64 {
        return Int64(floor(self.timeIntervalSince1970 * 1000))
    }
    var timestampDelta: UInt {
        return UInt(max(0, MobileMessaging.date.now.timeIntervalSinceReferenceDate - self.timeIntervalSinceReferenceDate))
    }
}

var isTestingProcessRunning: Bool {
    return ProcessInfo.processInfo.arguments.contains("-IsStartedToRunTests")
}

extension Optional where Wrapped: Any {
    func ifSome<T>(_ block: (Wrapped) -> T?) -> T? {
        switch self {
        case .none:
            return nil
        case .some(let wr):
            return block(wr)
        }
    }
}

public extension UIDevice {
    func SYSTEM_VERSION_LESS_THAN(_ version: String) -> Bool {
        return self.systemVersion.compare(version, options: .numeric) == .orderedAscending
    }
}

open class MMDate {
    public var now: Date {
        return Date()
    }
    
    public func timeInterval(sinceNow timeInterval: TimeInterval) -> Date {
        return Date(timeIntervalSinceNow: timeInterval)
    }
    
    public func timeInterval(since1970 timeInterval: TimeInterval) -> Date {
        return Date(timeIntervalSince1970: timeInterval)
    }
    
    public func timeInterval(sinceReferenceDate timeInterval: TimeInterval) -> Date {
        return Date(timeIntervalSinceReferenceDate: timeInterval)
    }
    
    public func timeInterval(_ timeInterval: TimeInterval, since date: Date) -> Date {
        return Date(timeInterval: timeInterval, since: date)
    }
}

protocol UserNotificationCenterStorage {
    func getDeliveredMessages(completionHandler: @escaping ([MM_MTMessage]) -> Swift.Void)
}

class DefaultUserNotificationCenterStorage : UserNotificationCenterStorage {
    func getDeliveredMessages(completionHandler: @escaping ([MM_MTMessage]) -> Swift.Void) {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let messages = notifications
                .compactMap({
                    MM_MTMessage(payload: $0.request.content.userInfo,
                                 deliveryMethod: .local,
                                 seenDate: nil,
                                 deliveryReportDate: nil,
                                 seenStatus: .NotSeen,
                                 isDeliveryReportSent: false)
                })
            completionHandler(messages)
        }
    }
}

public protocol MMApplication {
    var applicationIconBadgeNumber: Int { get set }
    var applicationState: UIApplication.State { get }
    var isRegisteredForRemoteNotifications: Bool { get }
    func unregisterForRemoteNotifications()
    func registerForRemoteNotifications()
    var notificationEnabled: Bool? { get }
    var visibleViewController: UIViewController? { get }
}

extension UIApplication: MMApplication {
    public var visibleViewController: UIViewController? {
        return self.keyWindow?.visibleViewController
    }
}

extension MMApplication {
    var isInForegroundState: Bool {
        return applicationState == .active
    }
    
    public var notificationEnabled: Bool? {
        var notificationSettings: UNNotificationSettings?
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.global().async {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                notificationSettings = settings
                semaphore.signal()
            }
        }
        
        return semaphore.wait(timeout: DispatchTime.now() + .seconds(2)) == DispatchTimeoutResult.timedOut
            ?
            nil
            :
            notificationSettings?.alertSetting == UNNotificationSetting.enabled ||
            notificationSettings?.badgeSetting == UNNotificationSetting.enabled ||
            notificationSettings?.soundSetting == UNNotificationSetting.enabled
    }
}

class MainThreadedUIApplication: MMApplication {
    init() {
        
    }
    var app: UIApplication = UIApplication.shared
    var applicationIconBadgeNumber: Int {
        get {
            return getFromMain(getter: { app.applicationIconBadgeNumber })
        }
        set {
            inMainWait(block: { app.applicationIconBadgeNumber = newValue })
        }
    }
    
    var visibleViewController: UIViewController? {
        return getFromMain(getter: { app.keyWindow?.visibleViewController })
    }
    
    var applicationState: UIApplication.State {
        return getFromMain(getter: { app.applicationState })
    }
    
    var isRegisteredForRemoteNotifications: Bool {
        return getFromMain(getter: { app.isRegisteredForRemoteNotifications })
    }
    
    func unregisterForRemoteNotifications() {
        inMainWait { app.unregisterForRemoteNotifications() }
    }
    
    func registerForRemoteNotifications() {
        inMainWait { app.registerForRemoteNotifications() }
    }
}

func getDocumentsDirectory(filename: String) -> String {
    let applicationSupportPaths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
    let basePath = applicationSupportPaths.first ?? NSTemporaryDirectory()
    return URL(fileURLWithPath: basePath).appendingPathComponent("com.mobile-messaging.\(filename)", isDirectory: false).path
}

func applicationCodeChanged(newApplicationCode: String) -> Bool {
    let ci = InternalData.unarchive(from: InternalData.currentPath)
    if let currentApplicationCode = ci?.applicationCode {
        return newApplicationCode != currentApplicationCode
    } else if let currentApplicationCodeHash = ci?.applicationCodeHash {
        let newApplicationCodeHash = calculateAppCodeHash(newApplicationCode)
        return newApplicationCodeHash != currentApplicationCodeHash
    } else {
        return false
    }
}

extension String {
    static func localizedUserNotificationStringOrFallback(key: String?, args: [String]?, fallback: String?) -> String? {
        let ret: String?
        if let key = key {
            if let args = args {
                ret = NSString.localizedUserNotificationString(forKey: key, arguments: args)
            } else {
                ret = NSLocalizedString(key, comment: "") as String
            }
        } else {
            ret = fallback
        }
        return ret
    }
}

enum MessageStorageKind: String {
    case messages = "messages", chat = "chat"
}

extension UIImage {
    convenience init?(mm_named: String) {
        self.init(named: mm_named, in: MobileMessaging.bundle, compatibleWith: nil)
    }
}

let isDebug: Bool = {
    var isDebug = false
    // function with a side effect and Bool return value that we can pass into assert()
    func set(debug: Bool) -> Bool {
        isDebug = debug
        return isDebug
    }
    // assert:
    // "Condition is only evaluated in playgrounds and -Onone builds."
    // so isDebug is never changed to false in Release builds
    assert(set(debug: true))
    return isDebug
}()

func calculateAppCodeHash(_ appCode: String) -> String { return String(appCode.sha256().prefix(10)) }

extension Sequence {
    func forEachAsync(_ work: @escaping (Self.Iterator.Element, @escaping () -> Void) -> Void, completion: @escaping () -> Void) {
        let loopGroup = DispatchGroup()
        self.forEach { (el) in
            loopGroup.enter()
            work(el, {
                loopGroup.leave()
            })
        }
        
        loopGroup.notify(queue: DispatchQueue.global(qos: .default), execute: {
            completion()
        })
    }
}

extension UIColor {
    class func enabledCellColor() -> UIColor {
        return UIColor.white
    }
    class func disabledCellColor() -> UIColor {
        return UIColor.TABLEVIEW_GRAY().lighter(2)
    }
    
    func darker(_ percents: CGFloat) -> UIColor {
        var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        func reduce(_ value: CGFloat) -> CGFloat {
            let result: CGFloat = max(0, value - value * (percents/100.0))
            return result
        }
        return UIColor(red: reduce(r) , green: reduce(g), blue: reduce(b), alpha: a)
    }
    
    func lighter(_ percents: CGFloat) -> UIColor {
        var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
        self.getRed(&r, green: &g, blue: &b, alpha: &a)
        func reduce(_ value: CGFloat) -> CGFloat {
            let result: CGFloat = min(1, value + value * (percents/100.0))
            return result
        }
        return UIColor(red: reduce(r) , green: reduce(g), blue: reduce(b), alpha: a)
    }
    class func colorMod255(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor {
        return UIColor(red: r/255.0, green: g/255.0, blue: b/255.0, alpha: a)
    }
    class func TEXT_BLACK() -> UIColor {
        return UIColor.colorMod255(65, 65, 65)
    }
    class func TEXT_GRAY() -> UIColor {
        return UIColor.colorMod255(165, 165, 165)
    }
    class func TABBAR_TITLE_BLACK() -> UIColor {
        return UIColor.colorMod255(90, 90, 90)
    }
    class func ACTIVE_TINT() -> UIColor {
        return UIColor.MAIN()
    }
    class func TABLEVIEW_GRAY() -> UIColor {
        return UIColor.colorMod255(239, 239, 244)
    }
    class func MAIN() -> UIColor {
        #if IO
        return UIColor.colorMod255(234, 55, 203)
        #else
        return UIColor.colorMod255(239, 135, 51)
        #endif
    }
    class func MAIN_MED_DARK() -> UIColor {
        return UIColor.MAIN().darker(25)
    }
    class func MAIN_DARK() -> UIColor {
        return UIColor.MAIN().darker(50)
    }
    class func CHAT_MESSAGE_COLOR(_ isYours: Bool) -> UIColor {
        if (isYours == true) {
            return UIColor.colorMod255(253, 242, 229)
        } else {
            return UIColor.white
        }
    }
    class func CHAT_MESSAGE_FONT_COLOR(_ isYours: Bool) -> UIColor {
        if (isYours == true) {
            return UIColor.colorMod255(73, 158, 90)
        } else {
            return UIColor.darkGray
        }
    }
    class func TABLE_SEPARATOR_COLOR() -> UIColor {
        return UIColor.colorMod255(210, 209, 213)
    }
    class func GREEN() -> UIColor {
        return UIColor.colorMod255(127, 211, 33)
    }
    class func RED() -> UIColor {
        return UIColor.colorMod255(243, 27, 0)
    }
    
    public convenience init(hexString: String, alpha: CGFloat = 1.0) {
        let hexString: String = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        if (hexString.hasPrefix("#")) {
            scanner.scanLocation = 1
        }
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        self.init(red:red, green:green, blue:blue, alpha:alpha)
    }
    
    public func mmHexStringFromColor() -> String {
        guard let components = self.cgColor.components,
              components.count == 3 else {
            return "#000000" // case for .black
        }
        let r: CGFloat = components[0]
        let g: CGFloat = components[1]
        let b: CGFloat = components[2]
        let hexString = String.init(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
        return hexString
     }
}

public extension Optional {
    var orNil : String {
        if self == nil {
            return "nil"
        }
        if "\(Wrapped.self)" == "String" {
            return "\"\(self!)\""
        }
        return "\(self!)"
    }
}

extension URL {
    static func attachmentDownloadDestinationFolderUrl(appGroupId: String?) -> URL {
        let fileManager = FileManager.default
        let tempFolderUrl: URL
        if let appGroupId = appGroupId, let appGroupContainerUrl = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) {
            tempFolderUrl = appGroupContainerUrl.appendingPathComponent("Library/Caches")
        } else {
            tempFolderUrl = URL.init(fileURLWithPath: NSTemporaryDirectory())
        }
        
        var destinationFolderURL = tempFolderUrl.appendingPathComponent("com.mobile-messaging.rich-notifications-attachments", isDirectory: true)
        
        var isDir: ObjCBool = true
        if !fileManager.fileExists(atPath: destinationFolderURL.path, isDirectory: &isDir) {
            do {
                try fileManager.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true, attributes: nil)
            } catch _ {
                destinationFolderURL = tempFolderUrl
            }
        }
        return destinationFolderURL
    }
    
    static func attachmentDownloadDestinatioUrl(sourceUrl: URL, appGroupId: String?) -> URL {
        return URL.attachmentDownloadDestinationFolderUrl(appGroupId:appGroupId).appendingPathComponent(sourceUrl.absoluteString.sha256() + "." + sourceUrl.pathExtension)
    }
}

extension Bundle {
    static var mainAppBundle: Bundle {
        var bundle = Bundle.main
        if bundle.bundleURL.pathExtension == "appex" {
            // Peel off two directory levels - MY_APP.app/PlugIns/MY_APP_EXTENSION.appex
            let url = bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            if let otherBundle = Bundle(url: url) {
                bundle = otherBundle
            }
        }
        return bundle
    }
    var appGroupId: String? {
        return self.object(forInfoDictionaryKey: "com.mobilemessaging.app_group") as? String
    }
}

extension Array where Element: Hashable {
    var asSet: Set<Element> {
        return Set(self)
    }
}

extension Set {
    var asArray: Array<Element> {
        return Array(self)
    }
}

public class ThreadSafeDict<T> {
    private var dict: [String: T] = [:]
    private var queue: DispatchQueue = DispatchQueue.init(label: "", qos: .default, attributes: [.concurrent])
    func set(value: T?, forKey key: String) {
        queue.async(group: nil, qos: .default, flags: .barrier) {
            self.dict[key] = value
        }
    }
    
    func getValue(forKey key: String) -> T? {
        var ret: T?
        queue.sync {
            ret = dict[key]
        }
        return ret
    }
    
    func reset() {
        queue.async(group: nil, qos: .default, flags: .barrier) {
            self.dict.removeAll()
        }
    }
}

extension UIWindow {
    var visibleViewController: UIViewController? {
        return UIWindow.getVisibleViewControllerFrom(self.rootViewController)
    }
    
    static func getVisibleViewControllerFrom(_ vc: UIViewController?) -> UIViewController? {
        if let nc = vc as? UINavigationController {
            return UIWindow.getVisibleViewControllerFrom(nc.visibleViewController)
        } else if let tc = vc as? UITabBarController {
            let moreNavigationController = tc.moreNavigationController
            if let visible = moreNavigationController.visibleViewController , visible.view.window != nil {
                return UIWindow.getVisibleViewControllerFrom(moreNavigationController)
            } else {
                return UIWindow.getVisibleViewControllerFrom(tc.selectedViewController)
            }
        } else {
            if let pvc = vc?.presentedViewController {
                return UIWindow.getVisibleViewControllerFrom(pvc)
            } else {
                return vc
            }
        }
    }
}
