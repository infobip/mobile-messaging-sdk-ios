//
//  MMGeoMessage.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation

enum MMRegionDataKeys: String {
	case Latitude = "latitude"
	case Longitude = "longitude"
	case Radius = "radiusInMeters"
	case Title = "title"
	case Identifier = "id"
	case ExpiryMillis = "expiry"
	case ExpiryDate = "expiryTime"
	case StartDate = "startTime"
	case Event = "event"
	case deliveryTime = "deliveryTime"
}

enum MMRegionDeliveryTimeKeys: String {
	case days = "days"
	case timeInterval = "timeInterval"
}

enum MMRegionEventDataKeys: String {
	case eventType = "type"
	case eventLimit = "limit"
	case eventTimeout = "timeoutInMinutes"
	case occuringCounter = "rate"
	case eventLastOccur = "lastOccur"
}

enum MMRegionEventType: String {
	case entry
	case exit
}

extension MTMessage {
	convenience init?(managedObject: MessageManagedObject) {
		guard let payload = managedObject.payload else {
			return nil
		}
		
		self.init(payload: payload, createdDate: managedObject.creationDate)
	}
}

final public class MMGeoMessage: MTMessage {
	public let regions: Set<MMRegion>
	
	public override init?(payload: APNSPayload, createdDate: NSDate) {
		guard let internalData = payload[MMAPIKeys.kInternalData] as? StringKeyPayload, let geoRegionsData = internalData[MMAPIKeys.kGeo] as? [StringKeyPayload] else
		{
			return nil
		}
		self.regions = Set(geoRegionsData.flatMap(MMRegion.init))
		super.init(payload: payload, createdDate: createdDate)
		self.regions.forEach { $0.message = self }
	}
}

//MARK: Plist parsing, for migrate from old versions
enum MMPlistCampaignOrigin: Int {
	case Push = 0
	case Manual //old, for geo showcase support
}

enum MMPlistCampaignDataKeys: String {
	case Id = "id"
	case Title = "title"
	case Message = "message"
	case DateReceived = "receivedDate"
	case Regions = "regions"
	case Origin = "origin"
}

@available(*, deprecated, message="Used only for backward compatability. Since 1.3.0 the regions are stored in Core Data storage, not in the Plist")
func ==(lhs: MMPlistCampaign, rhs: MMPlistCampaign) -> Bool {
	return lhs.id == rhs.id
}

@available(*, deprecated, message="Used only for backward compatability. Since 1.3.0 the regions are stored in Core Data storage, not in the Plist")
final class MMPlistCampaign: Hashable, Equatable, CustomStringConvertible, DictionaryRepresentable {
    let id: String
    let title: String?
    let body: String?
    let dateReceived: NSDate
    let regions: Set<MMRegion>
	
	init?(id: String, title: String?, body: String?, sound: String?, dateReceived: NSDate, regions: Set<MMRegion> = Set<MMRegion>()) {
		guard !regions.isEmpty else
		{
			return nil
		}
		self.id = id
		self.title = title
		self.body = body
		self.dateReceived = dateReceived
		self.regions = regions
	}
	
	convenience init?(dictRepresentation dict: [String: AnyObject]) {
		guard let id = dict[MMPlistCampaignDataKeys.Id.rawValue] as? String,
			  let regionDicts = dict[MMPlistCampaignDataKeys.Regions.rawValue] as? [[String: AnyObject]] else
		{
			return nil
		}
		let regionObjects = regionDicts.flatMap(MMRegion.init)
		let date = dict[MMPlistCampaignDataKeys.DateReceived.rawValue] as? NSDate ?? NSDate()
		
		//if .Manual, then do not re-save at CoreData DB
		let origin = MMPlistCampaignOrigin(rawValue: dict[MMPlistCampaignDataKeys.Origin.rawValue] as? Int ?? 0) ?? .Manual
		if origin == .Manual {
			return nil
		}
		
		let title = dict[MMPlistCampaignDataKeys.Title.rawValue] as? String
		let body = dict[MMPlistCampaignDataKeys.Message.rawValue] as? String
		self.init(id: id, title: title, body: body, sound: nil, dateReceived: date, regions: Set(regionObjects))
	}
	
	var dictionaryRepresentation: [String: AnyObject] {
		var result = [String: AnyObject]()
		result[MMPlistCampaignDataKeys.Id.rawValue] = id
		result[MMPlistCampaignDataKeys.Title.rawValue] = title
		result[MMPlistCampaignDataKeys.Message.rawValue] = body
		result[MMPlistCampaignDataKeys.DateReceived.rawValue] = dateReceived
		result[MMPlistCampaignDataKeys.Regions.rawValue] = regions.map { $0.dictionaryRepresentation }
		
		assert(MMPlistCampaign(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	var hashValue: Int {
		return id.hashValue
	}
	
	var description: String {
		return "title=\(title), id=\(id)"
	}
}

public class MMDeliveryTime: NSObject, DictionaryRepresentable {
	public let timeInterval: MMDeliveryTimeInterval?
	public let days: Set<MMDay>?
	var isNow: Bool {
		return isAppropriateTime && isAppropriateDay
	}
	
	private var isAppropriateTime: Bool {
		guard let timeInterval = timeInterval else {
			return true
		}
		return timeInterval.isNow
	}

	private var isAppropriateDay: Bool {
		guard let days = days where !days.isEmpty else {
			return true
		}
		let calendar = NSCalendar(identifier: NSCalendarIdentifierGregorian)
		let now = NSDate() // don't change this, NSDate is needed since unit tests swizzle it
		let comps = calendar?.components([.Weekday], fromDate: now)
		if let systemWeekDay = comps?.weekday {
			let isoWeekdayNumber = systemWeekDay == 1 ? 7 : Int8(systemWeekDay - 1)
			if let day = MMDay(rawValue: isoWeekdayNumber) {
				return days.contains(day)
			} else {
				return false
			}
		}
		return false
	}
	
	required public convenience init?(dictRepresentation dict: [String: AnyObject]) {
		let interval = MMDeliveryTimeInterval(dictRepresentation: dict)
		let days: Set<MMDay>?
		if let daysArray = (dict[MMRegionDeliveryTimeKeys.days.rawValue] as? String)?.componentsSeparatedByString(",") {
			days = Set(daysArray.flatMap ({ dayNumString in
				if let dayNumInt8 = Int8(dayNumString) {
					return MMDay(rawValue: dayNumInt8)
				} else {
					return nil
				}
			}))
		} else {
			days = nil
		}
		self.init(timeInterval: interval, days: days)
	}
	
	var dictionaryRepresentation: [String : AnyObject] {
		var result = [String: AnyObject]()
		result += timeInterval?.dictionaryRepresentation
		if let days = days where !days.isEmpty {
			result[MMRegionDeliveryTimeKeys.days.rawValue] = Array(days).flatMap({ String($0.rawValue) }).joinWithSeparator(",")
		}
		assert(MMDeliveryTime(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	init(timeInterval: MMDeliveryTimeInterval?, days: Set<MMDay>?) {
		self.timeInterval = timeInterval
		self.days = days
	}
	
	var currentTestDate: NSDate? // dependency for testing purposes
}

@objc public enum MMDay: Int8 {
	case mo = 1, tu = 2, we = 3, th = 4, fr = 5, sa = 6, su = 7
}

public class MMDeliveryTimeInterval: NSObject, DictionaryRepresentable {
	static let timeIntervalSeparator = "/"
	let fromTime: String
	let toTime: String

	init(fromTime: String, toTime: String) {
		self.fromTime = fromTime
		self.toTime = toTime
	}

	var isNow: Bool {
		return MMDeliveryTimeInterval.isTime(NSDate(), between: fromTime, and: toTime)
	}
	
	/// Checks if `time` is in the interval defined with two time strings `fromTime` and `toTime` in ISO 8601 formats: `hhmm`
	class func isTime(time: NSDate, between fromTime: String, and toTime: String) -> Bool {
		
		let comps = NSCalendar.autoupdatingCurrentCalendar().components([.Hour, .Minute], fromDate: time)
		let h = comps.hour
		let m = comps.minute
		
		guard let fromH = Int(fromTime.substringWithRange(fromTime.startIndex..<fromTime.startIndex.advancedBy(2))),
			let fromM = Int(fromTime.substringWithRange(fromTime.startIndex.advancedBy(2)..<fromTime.endIndex)),
			let toH = Int(toTime.substringWithRange(toTime.startIndex..<toTime.startIndex.advancedBy(2))),
			let toM = Int(toTime.substringWithRange(toTime.startIndex.advancedBy(2)..<toTime.endIndex)) else
		{
			return false
		}
		
		let from = fromH * 60 + fromM
		let to = toH * 60 + toM
		let now = h * 60 + m
		
		if from <= to {
			return from <= now && now <= to
		} else {
			return from <= now || now <= to
		}
	}

	convenience public required init?(dictRepresentation dict: [String: AnyObject]) {
		if let comps = (dict[MMRegionDeliveryTimeKeys.timeInterval.rawValue] as? String)?.componentsSeparatedByString(MMDeliveryTimeInterval.timeIntervalSeparator),
			let from = comps.first,
			let to = comps.last where comps.count == 2
		{
			self.init(fromTime: from, toTime: to)
		} else {
			return nil
		}
	}
	
	var dictionaryRepresentation: [String: AnyObject] {
		var result = [String: AnyObject]()
		result[MMRegionDeliveryTimeKeys.timeInterval.rawValue] = "\(fromTime)\(MMDeliveryTimeInterval.timeIntervalSeparator)\(toTime)"
		assert(MMDeliveryTimeInterval(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
}

final public class MMRegion: NSObject, DictionaryRepresentable {
	public let deliveryTime: MMDeliveryTime?
	public let identifier: String
	public let startDate: NSDate
	public let expiryDate: NSDate
	let expiryDateString: NSString
	let startDateString: NSString
	public let center: CLLocationCoordinate2D
	public let radius: Double
	public let title: String
	public weak var message: MMGeoMessage?
	public var isLive: Bool {
		let validEventExists = events.contains { $0.isValid }
		return validEventExists && NSDate().compare(expiryDate) == .OrderedAscending && NSDate().compare(startDate) != .OrderedAscending
	}
	
	public var isNowAppropriateTimeForEntryNotification: Bool {
		return isNowAppropriateTimeForNotification(for: .entry)
	}
	
	public var isNowAppropriateTimeForExitNotification: Bool {
		return isNowAppropriateTimeForNotification(for: .exit)
	}
	
	public var circularRegion: CLCircularRegion {
		return CLCircularRegion(center: center, radius: radius, identifier: identifier)
	}
	
	init?(identifier: String, center: CLLocationCoordinate2D, radius: Double, title: String, expiryDateString: String, startDateString: String, deliveryTime: MMDeliveryTime?, events: [MMRegionEvent]) {
		guard let expiryDate = NSDateStaticFormatters.ISO8601SecondsFormatter.dateFromString(expiryDateString), let startDate = NSDateStaticFormatters.ISO8601SecondsFormatter.dateFromString(startDateString) where radius > 0 else
		{
			return nil
		}
		self.title = title
		self.center = center
		self.radius = max(100, radius)
		self.identifier = identifier
		self.expiryDateString = expiryDateString
		self.expiryDate = expiryDate
		self.startDateString = startDateString
		self.startDate = startDate
		self.deliveryTime = deliveryTime
		self.events = events.isEmpty ? [MMRegionEvent.defaultEvent] : events
	}
	
	@available(*, deprecated, message="Used only for backward compatability. Expiry date format is changed since 1.3.0 from millisecond timestamp to IOS8601 date string with the seconds granularity")
	public init?(identifier: String, center: CLLocationCoordinate2D, radius: Double, title: String, expiryms: NSTimeInterval) {
		guard radius > 0 && expiryms > 0 else
		{
			return nil
		}
		self.title = title
		self.center = center
		self.radius = max(100, radius)
		self.identifier = identifier
		self.expiryDate = NSDate(timeIntervalSince1970: expiryms/1000)
		self.expiryDateString = NSDateStaticFormatters.ISO8601SecondsFormatter.stringFromDate(self.expiryDate)
		self.startDate = NSDate(timeIntervalSinceReferenceDate: 0)
		self.startDateString = NSDateStaticFormatters.ISO8601SecondsFormatter.stringFromDate(self.startDate)
		self.deliveryTime = nil // old versions didn't have this attribute, so nil it is
		self.events = [MMRegionEvent.defaultEvent]
	}
	
	public override var description: String {
		return "\(title), radius \(radius)m, expiration \(expiryDate): \(center.longitude) \(center.latitude)"
	}
	
	public convenience init?(dictRepresentation dict: [String: AnyObject]) {
		guard let lat = dict[MMRegionDataKeys.Latitude.rawValue] as? Double,
			let lon = dict[MMRegionDataKeys.Longitude.rawValue] as? Double,
			let title = dict[MMRegionDataKeys.Title.rawValue] as? String,
			let identifier = dict[MMRegionDataKeys.Identifier.rawValue] as? String,
			let radius = dict[MMRegionDataKeys.Radius.rawValue] as? Double else
		{
			return nil
		}
		
		if let expiryDateString = dict[MMRegionDataKeys.ExpiryDate.rawValue] as? String {
			let startDateString = dict[MMRegionDataKeys.StartDate.rawValue] as? String ?? NSDateStaticFormatters.ISO8601SecondsFormatter.stringFromDate(NSDate(timeIntervalSinceReferenceDate: 0))
			
			let events: [MMRegionEvent]
			if let eventDicts = dict[MMRegionDataKeys.Event.rawValue] as? [[String: AnyObject]] {
				events = eventDicts.flatMap(MMRegionEvent.init)
			} else {
				events = [MMRegionEvent.defaultEvent]
			}
			
			let deliveryTime: MMDeliveryTime?
			if let deliveryTimeDict = dict[MMRegionDataKeys.deliveryTime.rawValue] as? [String: AnyObject] {
				deliveryTime = MMDeliveryTime(dictRepresentation: deliveryTimeDict)
			} else {
				deliveryTime = nil
			}
			self.init(identifier: identifier, center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: radius, title: title, expiryDateString: expiryDateString, startDateString: startDateString, deliveryTime: deliveryTime, events: events)
		} else if let expiryms = dict[MMRegionDataKeys.ExpiryMillis.rawValue] as? Double {
			self.init(identifier: identifier, center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: radius, title: title, expiryms: expiryms)
		} else {
			return nil
		}
	}
	
	public var dictionaryRepresentation: [String: AnyObject] {
		var result = [String: AnyObject]()
		result[MMRegionDataKeys.Latitude.rawValue] = center.latitude
		result[MMRegionDataKeys.Longitude.rawValue] = center.longitude
		result[MMRegionDataKeys.Radius.rawValue] = radius
		result[MMRegionDataKeys.Title.rawValue] = title
		result[MMRegionDataKeys.ExpiryDate.rawValue] = expiryDateString
		result[MMRegionDataKeys.Identifier.rawValue] = identifier
		result[MMRegionDataKeys.StartDate.rawValue] = startDateString
		result[MMRegionDataKeys.Event.rawValue] = events.map{$0.dictionaryRepresentation}
		result[MMRegionDataKeys.deliveryTime.rawValue] = deliveryTime?.dictionaryRepresentation
		assert(MMRegion(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}

	public override var hashValue: Int {
		return identifier.hashValue
	}
	
	let events: [MMRegionEvent]
	
	func triggerEvent(for type: MMRegionEventType) {
		events.filter{$0.type == type}.first?.occur()
	}
	
	func isLive(for type: MMRegionEventType) -> Bool {
		return isLive && (events.filter{$0.type == type}.first?.isValid) ?? false
	}
	private func isNowAppropriateTimeForNotification(for type: MMRegionEventType) -> Bool {
		return deliveryTime?.isNow ?? true && isLive(for: type)
	}
}

public func ==(lhs: MMRegion, rhs: MMRegion) -> Bool {
	return lhs.identifier == rhs.identifier
}

final class MMRegionEvent: DictionaryRepresentable {
	let type: MMRegionEventType
	let limit: Int					//how many times this event can occur, 0 means unlimited
	let timeout: Int			    //minutes till next possible event
	var occuringCounter: Int = 0
	var lastOccuring: NSDate?
	
	var isValid: Bool {
		if limit != 0 && occuringCounter >= limit {
			return false
		}
		
		return lastOccuring?.dateByAddingTimeInterval(NSTimeInterval(timeout * 60)).compare(NSDate()) != .OrderedDescending
	}
	
	func occur() {
		occuringCounter += 1
		lastOccuring = NSDate()
	}
	
	init?(dictRepresentation dict: [String: AnyObject]) {
		guard let typeString = dict[MMRegionEventDataKeys.eventType.rawValue] as? String,
			  let type = MMRegionEventType(rawValue: typeString),
			  let limit = dict[MMRegionEventDataKeys.eventLimit.rawValue] as? Int else
		{
			return nil
		}
		self.type = type
		self.limit = limit
		self.timeout = dict[MMRegionEventDataKeys.eventTimeout.rawValue] as? Int ?? 0
		self.occuringCounter = dict[MMRegionEventDataKeys.occuringCounter.rawValue] as? Int ?? 0
		self.lastOccuring = dict[MMRegionEventDataKeys.eventLastOccur.rawValue] as? NSDate ?? nil
	}
	
	var dictionaryRepresentation: [String: AnyObject] {
		var result = [String: AnyObject]()
		result[MMRegionEventDataKeys.eventType.rawValue] = type.rawValue
		result[MMRegionEventDataKeys.eventLimit.rawValue] = limit
		result[MMRegionEventDataKeys.eventTimeout.rawValue] = timeout
		result[MMRegionEventDataKeys.occuringCounter.rawValue] = occuringCounter
		result[MMRegionEventDataKeys.eventLastOccur.rawValue] = lastOccuring
		assert(MMRegionEvent(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	private class var defaultEvent: MMRegionEvent {
		let defaultDict: [String: AnyObject] = [MMRegionEventDataKeys.eventType.rawValue: MMRegionEventType.entry.rawValue,
		                                        MMRegionEventDataKeys.eventLimit.rawValue: 1,
		                                        MMRegionEventDataKeys.eventTimeout.rawValue: 0]
		return MMRegionEvent(dictRepresentation: defaultDict)!
	}
}