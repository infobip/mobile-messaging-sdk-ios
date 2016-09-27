//
//  MMCampaign.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation

@available(*, deprecated)
enum MMCampaignOrigin: Int {
	case Push = 0
	case Manual //old, for geo showcase support
}

@available(*, deprecated)
enum MMCampaignDataKeys: String {
	case Id = "id"
	case Title = "title"
	case Message = "message"
	case DateReceived = "receivedDate"
	case Regions = "regions"
	case Origin = "origin"
}

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
}

enum MMRegionEventDataKeys: String {
	case eventType = "type"
	case eventLimit = "limit"
	case eventTimeout = "timeoutInMinutes"
	case eventRate = "rate"
	case eventLastOccur = "lastOccur"
}

enum MMRegionEventType: String {
	case entry
	case exit
}

protocol PlistArchivable {
	init?(dictRepresentation dict: [String: AnyObject])
	var dictionaryRepresentation: [String: AnyObject] {get}
}

extension MMMessage {
	
	public var isGeoMessage: Bool {
		return self.geoRegionsData != nil
	}
	
	convenience init?(managedObject: MessageManagedObject) {
		guard let payload = managedObject.payload else {
			return nil
		}
		
		self.init(payload: payload)
	}
}

final public class MMGeoCampaign: Hashable, Equatable {
	public var messageId: String {
		return message.messageId
	}
	public let message: MMMessage
	public let regions: Set<MMRegion>
	
	init?(message: MMMessage) {
		guard let geoRegionsData = message.geoRegionsData else {
			return nil
		}
		self.message = message
		self.regions = Set(geoRegionsData.flatMap(MMRegion.init))
		self.regions.forEach{$0.campaign = self}
	}
	
	public var hashValue: Int {
		return message.messageId.hashValue
	}
}

public func ==(lhs: MMGeoCampaign, rhs: MMGeoCampaign) -> Bool {
	return lhs.messageId == rhs.messageId
}

@available(*, deprecated)
final public class MMCampaign: Hashable, Equatable, CustomStringConvertible, PlistArchivable {
    public let id: String
    public let title: String?
    public let body: String?
    public let dateReceived: NSDate
    public let regions: Set<MMRegion>
	
	init?(id: String,
	      title: String?,
	      body: String?,
	      sound: String?,
	      dateReceived: NSDate,
	      regions: Set<MMRegion> = Set<MMRegion>(),
	      customPayload: [String: AnyObject]?) {
		
		guard !regions.isEmpty else {
			return nil
		}
        self.id = id
        self.title = title
        self.body = body
        self.dateReceived = dateReceived
        self.regions = regions
    }
	
	convenience init?(dictRepresentation dict: [String: AnyObject]) {
		guard let id = dict[MMCampaignDataKeys.Id.rawValue] as? String,
			  let regionDicts = dict[MMCampaignDataKeys.Regions.rawValue] as? [[String:AnyObject]] else
		{
			return nil
		}
		let regionObjects = regionDicts.flatMap(MMRegion.init)
		let date = dict[MMCampaignDataKeys.DateReceived.rawValue] as? NSDate ?? NSDate()
		
		//if .Manual, then do not re-save at CoreData DB
		let origin = MMCampaignOrigin(rawValue: dict[MMCampaignDataKeys.Origin.rawValue] as? Int ?? 0) ?? .Manual
		if origin == .Manual {
			return nil
		}
		
		self.init(id: id,
		          title: dict[MMCampaignDataKeys.Title.rawValue] as? String ?? "",
		          body: dict[MMCampaignDataKeys.Message.rawValue] as? String ?? "",
		          sound: nil,
		          dateReceived: date,
		          regions: Set(regionObjects),
		          customPayload: nil)
	}
	
	var dictionaryRepresentation: [String: AnyObject] {
		var result = [String: AnyObject]()
		result[MMCampaignDataKeys.Id.rawValue] = id
		result[MMCampaignDataKeys.Title.rawValue] = title
		result[MMCampaignDataKeys.Message.rawValue] = body
		result[MMCampaignDataKeys.DateReceived.rawValue] = dateReceived
		result[MMCampaignDataKeys.Regions.rawValue] = regions.map { $0.dictionaryRepresentation }
		
		assert(MMCampaign(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	public var hashValue: Int {
		return id.hashValue
	}
	
	public var description: String {
		return "title=\(title), id=\(id)"
	}
}

public func ==(lhs: MMCampaign, rhs: MMCampaign) -> Bool {
    return lhs.id == rhs.id
}

final public class MMRegion: NSObject, PlistArchivable {
	public let identifier: String
	public let startDate: NSDate
	public let expiryDate: NSDate
	let expiryDateString: NSString
	let startDateString: NSString
	public let center: CLLocationCoordinate2D
	public let radius: Double
	public let title: String
	weak var campaign: MMGeoCampaign?
	public var isLive: Bool {
		let validEventExists = events.contains{$0.isValid}
		return validEventExists && NSDate().compare(expiryDate) == .OrderedAscending && NSDate().compare(startDate) != .OrderedAscending
	}
	
	func triggerEvent(for type: MMRegionEventType) {
		events.filter{$0.type == type}.first?.occur()
	}
	
	func isLive(for type: MMRegionEventType) -> Bool {
		return isLive && (events.filter{$0.type == type}.first?.isValid) ?? false
	}
	
	public var circularRegion: CLCircularRegion {
		return CLCircularRegion(center: center, radius: radius, identifier: identifier)
	}
	
	var events: [MMRegionEvent] = {
		return [MMRegionEvent.makeDefault(ofType: .entry)]
	}()
	
	public init?(identifier: String, center: CLLocationCoordinate2D, radius: Double, title: String, expiryDateString: String, startDateString: String) {
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
		let startDateString = (dict[MMRegionDataKeys.StartDate.rawValue] as? String) ?? NSDateStaticFormatters.ISO8601SecondsFormatter.stringFromDate(NSDate(timeIntervalSinceReferenceDate: 0))
		if let expiryDateString = dict[MMRegionDataKeys.ExpiryDate.rawValue] as? String {
			self.init(identifier: identifier, center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: radius, title: title, expiryDateString: expiryDateString, startDateString: startDateString)
		} else if let expiryms = dict[MMRegionDataKeys.ExpiryMillis.rawValue] as? Double {
			self.init(identifier: identifier, center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: radius, title: title, expiryms: expiryms)
		} else {
			return nil
		}
		
		if let eventDicts = dict[MMRegionDataKeys.Event.rawValue] as? [[String:AnyObject]] {
			self.events = eventDicts.flatMap(MMRegionEvent.init)
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
		result[MMRegionDataKeys.Event.rawValue] = events.flatMap{$0.dictionaryRepresentation}
		
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

final class MMRegionEvent: PlistArchivable {
	let type: MMRegionEventType
	let limit: UInt					//how many times this event can occur, 0 means unlimited
	let timeout: UInt			    //minutes till next possible event
	
	var rate: UInt = 0
	var lastOccur: NSDate?
	
	var isValid: Bool {
		if limit != 0 && rate >= limit {
			return false
		}
		
		return lastOccur?.dateByAddingTimeInterval(NSTimeInterval(timeout*60)).compare(NSDate()) != .OrderedDescending
	}
	
	func occur() {
		rate += 1
		lastOccur = NSDate()
	}
	
	init?(dictRepresentation dict: [String: AnyObject]) {
		guard let typeString = dict[MMRegionEventDataKeys.eventType.rawValue] as? String,
			  let type = MMRegionEventType(rawValue: typeString),
			  let limit = dict[MMRegionEventDataKeys.eventLimit.rawValue] as? UInt else {
				return nil
		}
		self.type = type
		self.limit = limit
		self.timeout = dict[MMRegionEventDataKeys.eventTimeout.rawValue] as? UInt ?? 0
		self.rate = dict[MMRegionEventDataKeys.eventRate.rawValue] as? UInt ?? 0
		self.lastOccur = dict[MMRegionEventDataKeys.eventLastOccur.rawValue] as? NSDate ?? nil
	}
	
	var dictionaryRepresentation: [String: AnyObject] {
		var result = [String: AnyObject]()
		result[MMRegionEventDataKeys.eventType.rawValue] = type.rawValue
		result[MMRegionEventDataKeys.eventLimit.rawValue] = limit
		result[MMRegionEventDataKeys.eventTimeout.rawValue] = timeout
		result[MMRegionEventDataKeys.eventRate.rawValue] = rate
		result[MMRegionEventDataKeys.eventLastOccur.rawValue] = lastOccur
		assert(MMRegionEvent(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	private class func makeDefault(ofType type: MMRegionEventType) -> MMRegionEvent {
		let defaultDict: [String: AnyObject] = [MMRegionEventDataKeys.eventType.rawValue: type.rawValue,
		                                        MMRegionEventDataKeys.eventLimit.rawValue: 1,
		                                        MMRegionEventDataKeys.eventTimeout.rawValue: 0]
		return MMRegionEvent(dictRepresentation: defaultDict)!
	}
}