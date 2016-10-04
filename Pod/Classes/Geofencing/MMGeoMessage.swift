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

public typealias DictionaryRepresentation = [String: Any]

protocol PlistArchivable {
	init?(dictRepresentation dict: DictionaryRepresentation)
	var dictionaryRepresentation: DictionaryRepresentation {get}
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
	
	public override init?(payload: APNSPayload, createdDate: Date) {
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

final class MMPlistCampaign: Hashable, Equatable, CustomStringConvertible, PlistArchivable {
    let id: String
    let title: String?
    let body: String?
    let dateReceived: Date
    let regions: Set<MMRegion>
	
	init?(id: String, title: String?, body: String?, sound: String?, dateReceived: Date, regions: Set<MMRegion> = Set<MMRegion>()) {
		guard !regions.isEmpty else {
			return nil
		}
        self.id = id
        self.title = title
        self.body = body
        self.dateReceived = dateReceived
        self.regions = regions
    }
	
	convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		guard let id = dict[MMPlistCampaignDataKeys.Id.rawValue] as? String,
			  let regionDicts = dict[MMPlistCampaignDataKeys.Regions.rawValue] as? [DictionaryRepresentation] else
		{
			return nil
		}
		let regionObjects = regionDicts.flatMap(MMRegion.init)
		let date = dict[MMPlistCampaignDataKeys.DateReceived.rawValue] as? Date ?? Date()
		
		//if .Manual, then do not re-save at CoreData DB
		let origin = MMPlistCampaignOrigin(rawValue: dict[MMPlistCampaignDataKeys.Origin.rawValue] as? Int ?? 0) ?? .Manual
		if origin == .Manual {
			return nil
		}
		
		let title = dict[MMPlistCampaignDataKeys.Title.rawValue] as? String
		let body = dict[MMPlistCampaignDataKeys.Message.rawValue] as? String
		self.init(id: id, title: title, body: body, sound: nil, dateReceived: date, regions: Set(regionObjects))
	}
	
	var dictionaryRepresentation: DictionaryRepresentation {
		var result = DictionaryRepresentation()
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

func ==(lhs: MMPlistCampaign, rhs: MMPlistCampaign) -> Bool {
    return lhs.id == rhs.id
}

final public class MMRegion: NSObject, PlistArchivable {
	public let identifier: String
	public let startDate: Date
	public let expiryDate: Date
	let expiryDateString: NSString
	let startDateString: NSString
	public let center: CLLocationCoordinate2D
	public let radius: Double
	public let title: String
	public weak var message: MMGeoMessage?
	public var isLive: Bool {
		let validEventExists = events.contains{$0.isValid}
		return validEventExists && Date().compare(expiryDate) == .orderedAscending && Date().compare(startDate) != .orderedAscending
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
		guard let expiryDate = DateStaticFormatters.ISO8601SecondsFormatter.date(from: expiryDateString), let startDate = DateStaticFormatters.ISO8601SecondsFormatter.date(from: startDateString) , radius > 0 else
		{
			return nil
		}
		self.title = title
		self.center = center
		self.radius = max(100, radius)
		self.identifier = identifier
		self.expiryDateString = expiryDateString as NSString
		self.expiryDate = expiryDate
		self.startDateString = startDateString as NSString
		self.startDate = startDate
	}
	
	@available(*, deprecated, message: "Used only for backward compatability. Expiry date format is changed since 1.3.0 from millisecond timestamp to IOS8601 date string with the seconds granularity")
	public init?(identifier: String, center: CLLocationCoordinate2D, radius: Double, title: String, expiryms: TimeInterval) {
		guard radius > 0 && expiryms > 0 else
		{
			return nil
		}
		self.title = title
		self.center = center
		self.radius = max(100, radius)
		self.identifier = identifier
		self.expiryDate = Date(timeIntervalSince1970: expiryms/1000)
		self.expiryDateString = DateStaticFormatters.ISO8601SecondsFormatter.string(from: self.expiryDate) as NSString
		self.startDate = Date(timeIntervalSinceReferenceDate: 0)
		self.startDateString = DateStaticFormatters.ISO8601SecondsFormatter.string(from: self.startDate) as NSString
	}
	
	public override var description: String {
		return "\(title), radius \(radius)m, expiration \(expiryDate): \(center.longitude) \(center.latitude)"
	}
	
	public convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		guard let lat = dict[MMRegionDataKeys.Latitude.rawValue] as? Double,
			let lon = dict[MMRegionDataKeys.Longitude.rawValue] as? Double,
			let title = dict[MMRegionDataKeys.Title.rawValue] as? String,
			let identifier = dict[MMRegionDataKeys.Identifier.rawValue] as? String,
			let radius = dict[MMRegionDataKeys.Radius.rawValue] as? Double else
		{
			return nil
		}
		let startDateString = (dict[MMRegionDataKeys.StartDate.rawValue] as? String) ?? DateStaticFormatters.ISO8601SecondsFormatter.string(from: Date(timeIntervalSinceReferenceDate: 0))
		if let expiryDateString = dict[MMRegionDataKeys.ExpiryDate.rawValue] as? String {
			self.init(identifier: identifier, center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: radius, title: title, expiryDateString: expiryDateString, startDateString: startDateString)
		} else if let expiryms = dict[MMRegionDataKeys.ExpiryMillis.rawValue] as? Double {
			self.init(identifier: identifier, center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: radius, title: title, expiryms: expiryms)
		} else {
			return nil
		}
		
		if let eventDicts = dict[MMRegionDataKeys.Event.rawValue] as? [DictionaryRepresentation] {
			self.events = eventDicts.flatMap(MMRegionEvent.init)
		}
	}
	
	public var dictionaryRepresentation: DictionaryRepresentation {
		var result = DictionaryRepresentation()
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
	let limit: Int					//how many times this event can occur, 0 means unlimited
	let timeout: Int			    //minutes till next possible event
	var rate: Int
	var lastOccur: Date?
	
	var isValid: Bool {
		if limit != 0 && rate >= limit {
			return false
		}
		
		return lastOccur?.addingTimeInterval(TimeInterval(timeout * 60)).compare(Date() as Date) != .orderedDescending
	}
	
	func occur() {
		rate += 1
		lastOccur = Date()
	}
	
	init?(dictRepresentation dict: DictionaryRepresentation) {
		guard let typeString = dict[MMRegionEventDataKeys.eventType.rawValue] as? String,
			  let type = MMRegionEventType(rawValue: typeString),
			  let limit = dict[MMRegionEventDataKeys.eventLimit.rawValue] as? Int else
		{
			return nil
		}
		self.type = type
		self.limit = limit
		self.timeout = dict[MMRegionEventDataKeys.eventTimeout.rawValue] as? Int ?? 0
		self.rate = dict[MMRegionEventDataKeys.eventRate.rawValue] as? Int ?? 0
		self.lastOccur = dict[MMRegionEventDataKeys.eventLastOccur.rawValue] as? Date ?? nil
	}
	
	var dictionaryRepresentation: DictionaryRepresentation {
		var result = DictionaryRepresentation()
		result[MMRegionEventDataKeys.eventType.rawValue] = type.rawValue
		result[MMRegionEventDataKeys.eventLimit.rawValue] = limit
		result[MMRegionEventDataKeys.eventTimeout.rawValue] = timeout
		result[MMRegionEventDataKeys.eventRate.rawValue] = rate
		result[MMRegionEventDataKeys.eventLastOccur.rawValue] = lastOccur
		assert(MMRegionEvent(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	fileprivate class func makeDefault(ofType type: MMRegionEventType) -> MMRegionEvent {
		let defaultDict: DictionaryRepresentation = [MMRegionEventDataKeys.eventType.rawValue: type.rawValue,
		                                        MMRegionEventDataKeys.eventLimit.rawValue: 1,
		                                        MMRegionEventDataKeys.eventTimeout.rawValue: 0]
		return MMRegionEvent(dictRepresentation: defaultDict)!
	}
}
