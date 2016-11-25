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


public typealias DictionaryRepresentation = [String: Any]
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
	public let startTime: Date
	public let expiryTime: Date
	public var isNotExpired: Bool {
		return campaignState == .Active && Date().compare(expiryTime) == .orderedAscending && Date().compare(startTime) != .orderedAscending
	}
	
	public var campaignState: CampaignState = .Active
	
	convenience init?(managedObject: MessageManagedObject) {
		guard let payload = managedObject.payload else {
			return nil
		}
		
		self.init(payload: payload, createdDate: managedObject.creationDate)
		self.campaignState = managedObject.campaignState
	}
	
	public override init?(payload: APNSPayload, createdDate: Date) {
		guard
			let internalData = payload[APNSPayloadKeys.kInternalData] as? StringKeyPayload,
			let geoRegionsData = internalData[APNSPayloadKeys.kInternalDataGeo] as? [StringKeyPayload],
			let expiryTimeString = internalData[MMCampaignDataKeys.expiryDate] as? String,

			let startTimeString = internalData[MMCampaignDataKeys.startDate] as? String ?? DateStaticFormatters.ISO8601SecondsFormatter.string(from: Date(timeIntervalSinceReferenceDate: 0)) as String?,
			let expiryTime = DateStaticFormatters.ISO8601SecondsFormatter.date(from: expiryTimeString),
			let startTime = DateStaticFormatters.ISO8601SecondsFormatter.date(from: startTimeString),
			let campaignId = internalData[MMCampaignDataKeys.campaignId] as? String
			else
		{
			return nil
		}
		self.campaignId = campaignId
		self.expiryTime = expiryTime
		self.startTime = startTime
		
		let deliveryTime: MMDeliveryTime?
		if let deliveryTimeDict = internalData[APNSPayloadKeys.kInternalDataDeliveryTime] as? DictionaryRepresentation {
			deliveryTime = MMDeliveryTime(dictRepresentation: deliveryTimeDict)
		} else {
			deliveryTime = nil
		}
		
		let evs: [MMRegionEvent]
		if let eventDicts = internalData[APNSPayloadKeys.kInternalDataEvent] as? [DictionaryRepresentation] {
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
		guard events.contains(where: {$0.type == type}) else {
			return false
		}
		let containsAnInvalidEvent = events.contains(where: {$0.isValid == false && $0.type == type})
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
		guard let days = days, !days.isEmpty else {
			return true
		}
		let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
		let now = NSDate() as Date // don't change this, NSDate is needed since unit tests swizzle it
		let comps = calendar.dateComponents(Set([Calendar.Component.weekday]), from: now)
		if let systemWeekDay = comps.weekday {
			let isoWeekdayNumber = systemWeekDay == 1 ? 7 : Int8(systemWeekDay - 1)
			if let day = MMDay(rawValue: isoWeekdayNumber) {
				return days.contains(day)
			} else {
				return false
			}
		}
		return false
	}
	
	required public convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		let interval = MMDeliveryTimeInterval(dictRepresentation: dict)
		let days: Set<MMDay>?

		if let daysArray = (dict[MMRegionDeliveryTimeKeys.days] as? String)?.components(separatedBy: ",") {
			days = Set(daysArray.flatMap ({ (dayNumString) -> MMDay? in
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
		var result = DictionaryRepresentation()
		result += timeInterval?.dictionaryRepresentation
		if let days = days , !days.isEmpty {
			result[MMRegionDeliveryTimeKeys.days] = Array(days).flatMap({ String($0.rawValue) }).joined(separator: ",")
		}
		assert(MMDeliveryTime(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	init(timeInterval: MMDeliveryTimeInterval?, days: Set<MMDay>?) {
		self.timeInterval = timeInterval
		self.days = days
	}
	
	var currentTestDate: Date? // dependency for testing purposes
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
		let now = NSDate() as Date // don't change this, NSDate is needed since unit tests swizzle it
		return MMDeliveryTimeInterval.isTime(now, between: fromTime, and: toTime)
	}
	
	/// Checks if `time` is in the interval defined with two time strings `fromTime` and `toTime` in ISO 8601 formats: `hhmm`
	class func isTime(_ time: Date, between fromTime: String, and toTime: String) -> Bool {
		let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
		let comps = calendar.dateComponents(Set([Calendar.Component.hour, Calendar.Component.minute]), from: time)
		if let nowH = comps.hour, let nowM = comps.minute {
			
			let fromTimeMinutesIdx = fromTime.index(fromTime.startIndex, offsetBy: 2)
			let toTimeMinutesIdx = toTime.index(toTime.startIndex, offsetBy: 2)
			guard let fromH = Int(fromTime.substring(with: fromTime.startIndex..<fromTimeMinutesIdx)),
				let fromM = Int(fromTime.substring(with: fromTimeMinutesIdx..<fromTime.endIndex)),
				let toH = Int(toTime.substring(with: toTime.startIndex..<toTimeMinutesIdx)),
				let toM = Int(toTime.substring(with: toTimeMinutesIdx..<toTime.endIndex)) else
			{
				return false
			}
			
			let from = fromH * 60 + fromM
			let to = toH * 60 + toM
			let now = nowH * 60 + nowM
			
			if from <= to {
				return from <= now && now <= to
			} else {
				return from <= now || now <= to
			}
		}
		return false
	}

	convenience public required init?(dictRepresentation dict: DictionaryRepresentation) {
		if let comps = (dict[MMRegionDeliveryTimeKeys.timeInterval] as? String)?.components(separatedBy: MMDeliveryTimeInterval.timeIntervalSeparator),
			let from = comps.first,
			let to = comps.last , comps.count == 2
		{
			self.init(fromTime: from, toTime: to)
		} else {
			return nil
		}
	}
	
	var dictionaryRepresentation: DictionaryRepresentation {
		var result = DictionaryRepresentation()
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
		var result = DictionaryRepresentation()
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
	var lastOccuring: Date?
	
	var isValid: Bool {
		if limit != 0 && occuringCounter >= limit {
			return false
		}
		
		return lastOccuring?.addingTimeInterval(TimeInterval(timeout * 60)).compare(Date()) != .orderedDescending
	}
	
	func occur() {
		occuringCounter += 1
		lastOccuring = Date()
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
		self.lastOccuring = dict[MMRegionEventDataKeys.eventLastOccur] as? Date ?? nil
	}
	
	var dictionaryRepresentation: DictionaryRepresentation {
		var result = DictionaryRepresentation()
		result[MMRegionEventDataKeys.eventType] = type.rawValue
		result[MMRegionEventDataKeys.eventLimit] = limit
		result[MMRegionEventDataKeys.eventTimeout] = timeout
		result[MMRegionEventDataKeys.occuringCounter] = occuringCounter
		result[MMRegionEventDataKeys.eventLastOccur] = lastOccuring
		assert(MMRegionEvent(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	

	fileprivate class var defaultEvent: MMRegionEvent {
		let defaultDict: DictionaryRepresentation = [MMRegionEventDataKeys.eventType: MMRegionEventType.entry.rawValue,
		                                             MMRegionEventDataKeys.eventLimit: 1,
		                                             MMRegionEventDataKeys.eventTimeout: 0]
		return MMRegionEvent(dictRepresentation: defaultDict)!
	}
}
