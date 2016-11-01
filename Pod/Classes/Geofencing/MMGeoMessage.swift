//
//  MMGeoMessage.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation
import CoreData

struct MMCampaignDataKeys {
	static let id = "id"
	static let title = "title"
	static let message = "message"
	static let dateReceived = "receivedDate"
	static let regions = "regions"
	static let origin = "origin"
	static let expiryDate = "expiryTime"
	static let startDate = "startTime"
	static let campaignId = "campaignId"
}

struct MMRegionDataKeys {
	static let latitude = "latitude"
	static let longitude = "longitude"
	static let radius = "radiusInMeters"
	static let title = "title"
	static let identifier = "id"
}

struct MMRegionDeliveryTimeKeys {
	static let days = "days"
	static let timeInterval = "timeInterval"
}

struct MMRegionEventDataKeys {
	static let eventType = "type"
	static let eventLimit = "limit"
	static let eventTimeout = "timeoutInMinutes"
	static let occuringCounter = "rate"
	static let eventLastOccur = "lastOccur"
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
	public let campaignId: String
	public let regions: Set<MMRegion>
	public let startTime: NSDate
	public let expiryTime: NSDate
	public var isNotExpired: Bool {
		return NSDate().compare(expiryTime) == .OrderedAscending && NSDate().compare(startTime) != .OrderedAscending
	}
	
	public override init?(payload: APNSPayload, createdDate: NSDate) {
		guard
			let internalData = payload[APNSPayloadKeys.kInternalData] as? StringKeyPayload,
			let geoRegionsData = internalData[APNSPayloadKeys.kInternalDataGeo] as? [StringKeyPayload],
			let expiryTimeString = internalData[MMCampaignDataKeys.expiryDate] as? String,
			let startTimeString = internalData[MMCampaignDataKeys.startDate] as? String ?? NSDateStaticFormatters.ISO8601SecondsFormatter.stringFromDate(NSDate(timeIntervalSinceReferenceDate: 0)) as String?,
			let expiryTime = NSDateStaticFormatters.ISO8601SecondsFormatter.dateFromString(expiryTimeString),
			let startTime = NSDateStaticFormatters.ISO8601SecondsFormatter.dateFromString(startTimeString),
			let campaignId = internalData[MMCampaignDataKeys.campaignId] as? String
			else
		{
			return nil
		}
		self.campaignId = campaignId
		self.expiryTime = expiryTime
		self.startTime = startTime
		
		let deliveryTime: MMDeliveryTime?
		if let deliveryTimeDict = internalData[APNSPayloadKeys.kInternalDataDeliveryTime] as? [String: AnyObject] {
			deliveryTime = MMDeliveryTime(dictRepresentation: deliveryTimeDict)
		} else {
			deliveryTime = nil
		}
		
		let evs: [MMRegionEvent]
		if let eventDicts = internalData[APNSPayloadKeys.kInternalDataEvent] as? [[String: AnyObject]] {
			evs = eventDicts.flatMap(MMRegionEvent.init)
		} else {
			evs = [MMRegionEvent.defaultEvent]
		}
		
		self.deliveryTime = deliveryTime
		self.events = evs
		self.regions = Set(geoRegionsData.flatMap(MMRegion.init))
		super.init(payload: payload, createdDate: createdDate)
		self.regions.forEach({ $0.message = self })
	}
	
	public var isNowAppropriateTimeForEntryNotification: Bool {
		return isNowAppropriateTimeForNotification(for: .entry)
	}
	
	public var isNowAppropriateTimeForExitNotification: Bool {
		return isNowAppropriateTimeForNotification(for: .exit)
	}
	
	//MARK: - Internal
	let deliveryTime: MMDeliveryTime?
	
	func isLive(for type: MMRegionEventType) -> Bool {
		
		guard events.contains({$0.type == type}) else {
			return false
		}
		let containsAnInvalidEvent = events.contains({$0.isValid == false && $0.type == type})
		return !containsAnInvalidEvent && isNotExpired
	}
	
	func isNowAppropriateTimeForNotification(for type: MMRegionEventType) -> Bool {
		return deliveryTime?.isNow ?? true && isLive(for: type)
	}
	
	let events: [MMRegionEvent]
}

public class MMDeliveryTime: NSObject, DictionaryRepresentable {
	public let timeInterval: MMDeliveryTimeInterval?
	public let days: Set<MMDay>?
	var isNow: Bool {
		return isNowAppropriateTime && isNowAppropriateDay
	}
	
	private var isNowAppropriateTime: Bool {
		guard let timeInterval = timeInterval else {
			return true
		}
		return timeInterval.isNow
	}
	
	private var isNowAppropriateDay: Bool {
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
	
	convenience required public init?(dictRepresentation dict: DictionaryRepresentation) {
		let interval = MMDeliveryTimeInterval(dictRepresentation: dict)
		let days: Set<MMDay>?
		if let daysArray = (dict[MMRegionDeliveryTimeKeys.days] as? String)?.componentsSeparatedByString(",") {
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
	
	var dictionaryRepresentation: DictionaryRepresentation {
		var result = [String: AnyObject]()
		result += timeInterval?.dictionaryRepresentation
		if let days = days where !days.isEmpty {
			result[MMRegionDeliveryTimeKeys.days] = Array(days).flatMap({ String($0) }).joinWithSeparator(",")
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
		
		guard
			let fromH = Int(fromTime.substringWithRange(fromTime.startIndex..<fromTime.startIndex.advancedBy(2))),
			let fromM = Int(fromTime.substringWithRange(fromTime.startIndex.advancedBy(2)..<fromTime.endIndex)),
			let toH = Int(toTime.substringWithRange(toTime.startIndex..<toTime.startIndex.advancedBy(2))),
			let toM = Int(toTime.substringWithRange(toTime.startIndex.advancedBy(2)..<toTime.endIndex))
			else
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
	
	convenience public required init?(dictRepresentation dict: DictionaryRepresentation) {
		if	let comps = (dict[MMRegionDeliveryTimeKeys.timeInterval] as? String)?.componentsSeparatedByString(MMDeliveryTimeInterval.timeIntervalSeparator),
			let from = comps.first,
			let to = comps.last where comps.count == 2
		{
			self.init(fromTime: from, toTime: to)
		} else {
			return nil
		}
	}
	
	var dictionaryRepresentation: DictionaryRepresentation {
		var result = [String: AnyObject]()
		result[MMRegionDeliveryTimeKeys.timeInterval] = "\(fromTime)\(MMDeliveryTimeInterval.timeIntervalSeparator)\(toTime)"
		assert(MMDeliveryTimeInterval(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
}

final public class MMRegion: NSObject, DictionaryRepresentable {
	public let identifier: String
	public let center: CLLocationCoordinate2D
	public let radius: Double
	public let title: String
	public weak var message: MMGeoMessage?
	
	public var circularRegion: CLCircularRegion {
		return CLCircularRegion(center: center, radius: radius, identifier: identifier)
	}
	
	init?(identifier: String, center: CLLocationCoordinate2D, radius: Double, title: String) {
		guard radius > 0 else
		{
			return nil
		}
		self.title = title
		self.center = center
		self.radius = max(100, radius)
		self.identifier = identifier
	}
	
	public override var description: String {
		return "\(title), radius \(radius)m: \(center.longitude) \(center.latitude)"
	}
	
	public convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		guard
			let lat = dict[MMRegionDataKeys.latitude] as? Double,
			let lon = dict[MMRegionDataKeys.longitude] as? Double,
			let title = dict[MMRegionDataKeys.title] as? String,
			let identifier = dict[MMRegionDataKeys.identifier] as? String,
			let radius = dict[MMRegionDataKeys.radius] as? Double
			else
		{
			return nil
		}
		
		self.init(identifier: identifier, center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: radius, title: title)
	}
	
	public var dictionaryRepresentation: DictionaryRepresentation {
		var result = [String: AnyObject]()
		result[MMRegionDataKeys.latitude] = center.latitude
		result[MMRegionDataKeys.longitude] = center.longitude
		result[MMRegionDataKeys.radius] = radius
		result[MMRegionDataKeys.title] = title
		result[MMRegionDataKeys.identifier] = identifier
		assert(MMRegion(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	public override var hashValue: Int {
		return identifier.hashValue
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
	
	init?(dictRepresentation dict: DictionaryRepresentation) {
		guard
			let typeString = dict[MMRegionEventDataKeys.eventType] as? String,
			let type = MMRegionEventType(rawValue: typeString),
			let limit = dict[MMRegionEventDataKeys.eventLimit] as? Int
			else
		{
			return nil
		}
		self.type = type
		self.limit = limit
		self.timeout = dict[MMRegionEventDataKeys.eventTimeout] as? Int ?? 0
		self.occuringCounter = dict[MMRegionEventDataKeys.occuringCounter] as? Int ?? 0
		self.lastOccuring = dict[MMRegionEventDataKeys.eventLastOccur] as? NSDate ?? nil
	}
	
	var dictionaryRepresentation: DictionaryRepresentation {
		var result = [String: AnyObject]()
		result[MMRegionEventDataKeys.eventType] = type.rawValue
		result[MMRegionEventDataKeys.eventLimit] = limit
		result[MMRegionEventDataKeys.eventTimeout] = timeout
		result[MMRegionEventDataKeys.occuringCounter] = occuringCounter
		result[MMRegionEventDataKeys.eventLastOccur] = lastOccuring
		assert(MMRegionEvent(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	class var defaultEvent: MMRegionEvent {
		let defaultDict: [String: AnyObject] = [MMRegionEventDataKeys.eventType: MMRegionEventType.entry.rawValue,
		                                        MMRegionEventDataKeys.eventLimit: 1,
		                                        MMRegionEventDataKeys.eventTimeout: 0]
		return MMRegionEvent(dictRepresentation: defaultDict)!
	}
}