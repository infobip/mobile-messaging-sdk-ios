//
//  MMCampaign.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation

public enum MMCampaignOrigin: Int {
	case Push = 0
	case Manual
}

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
}

protocol PlistArchivable {
	init?(dictRepresentation dict: [String: AnyObject])
	var dictionaryRepresentation: [String: AnyObject] {get}
}

final public class MMCampaign: Hashable, Equatable, CustomStringConvertible, PlistArchivable {
    public let id: String
    public let title: String
    public let message: String
    public let dateReceived: NSDate
    public var regions: Set<MMRegion>
	public let origin: MMCampaignOrigin
	
	public init?(id: String, origin: MMCampaignOrigin, title: String, message: String, dateReceived: NSDate, regions: Set<MMRegion> = Set<MMRegion>()) {
		guard origin == .Manual || (origin == .Push && !regions.isEmpty) else {
			return nil
		}
		self.origin = origin
        self.id = id
        self.title = title
        self.message = message
        self.dateReceived = dateReceived
        self.regions = regions
		for region in regions {
			region.campaign = self
		}
    }
	
	convenience init?(message: MMMessage) {
		guard let regionsData = message.geoRegions, let text = message.text else {
			return nil
		}
		let regions = Set(regionsData.flatMap(MMRegion.init))
		self.init(id: NSUUID().UUIDString, origin: .Push, title: text.mm_breakWithMaxLength(15), message: text, dateReceived: NSDate(), regions: regions)
	}
	
	
	convenience init?(dictRepresentation dict: [String: AnyObject]) {
		guard let id = dict[MMCampaignDataKeys.Id.rawValue] as? String, let regionDicts = dict[MMCampaignDataKeys.Regions.rawValue] as? [[String:AnyObject]] else
		{
			return nil
		}
		let regionObjects = regionDicts.flatMap(MMRegion.init)
		let date = dict[MMCampaignDataKeys.DateReceived.rawValue] as? NSDate ?? NSDate()
		let origin = MMCampaignOrigin(rawValue: dict[MMCampaignDataKeys.Origin.rawValue] as? Int ?? 0) ?? .Manual
		
		self.init(id: id, origin: origin, title: dict[MMCampaignDataKeys.Title.rawValue] as? String ?? "", message: dict[MMCampaignDataKeys.Message.rawValue] as? String ?? "", dateReceived: date, regions: Set(regionObjects))
	}
	
	var dictionaryRepresentation: [String: AnyObject] {
		var result = [String: AnyObject]()
		result[MMCampaignDataKeys.Id.rawValue] = id
		result[MMCampaignDataKeys.Title.rawValue] = title
		result[MMCampaignDataKeys.Message.rawValue] = message
		result[MMCampaignDataKeys.DateReceived.rawValue] = dateReceived
		result[MMCampaignDataKeys.Regions.rawValue] = regions.map { $0.dictionaryRepresentation }
		result[MMCampaignDataKeys.Origin.rawValue] = origin.rawValue
		
		assert(MMCampaign(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	public var hashValue: Int {
		return id.hashValue
	}
	
	public var description: String {
		return "title=\(title), id=\(id), origin=\(origin)"
	}
}

public func ==(lhs: MMCampaign, rhs: MMCampaign) -> Bool {
    return lhs.id == rhs.id
}

final public class MMRegion: NSObject, PlistArchivable {
	public let identifier: String
	public let expiryDate: NSDate
	let expiryDateString: NSString
	public let center: CLLocationCoordinate2D
	public let radius: Double
	public let title: String
	public weak var campaign: MMCampaign?
	public var isExpired: Bool {
		return NSDate().compare(expiryDate) == NSComparisonResult.OrderedDescending
	}
	public var circularRegion: CLCircularRegion {
		return CLCircularRegion(center: center, radius: radius, identifier: identifier)
	}
	
	public init?(identifier: String, center: CLLocationCoordinate2D, radius: Double, title: String, expiryDateString: String) {
		guard let expiry = NSDateStaticFormatters.ISO8601SecondsFormatter.dateFromString(expiryDateString) where radius > 0 else
		{
			return nil
		}
		self.title = title
		self.center = center
		self.radius = max(100, radius)
		self.identifier = identifier
		self.expiryDateString = expiryDateString
		self.expiryDate = expiry
	}
	
	@available(*, deprecated, message="Used only for backward compatability. Expiry date format is changed since 1.3.0 from millisecond timestamp to IOS8601 date string with the seconds granularity")
	init?(identifier: String, center: CLLocationCoordinate2D, radius: Double, title: String, expiryms: NSTimeInterval) {
		guard radius > 0 && expiryms > 0 else
		{
			return nil
		}
		self.title = title
		self.center = center
		self.radius = max(100, radius)
		self.identifier = identifier
		self.expiryDate = NSDate(timeIntervalSince1970: expiryms/1000)
		self.expiryDateString = NSDateStaticFormatters.ISO8601SecondsFormatter.stringFromDate(expiryDate)
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
			self.init(identifier: identifier, center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: radius, title: title, expiryDateString: expiryDateString)
		} else if let expiryms = dict[MMRegionDataKeys.ExpiryMillis.rawValue] as? Double {
			self.init(identifier: identifier, center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: radius, title: title, expiryms: expiryms)
		} else {
			return nil
		}
	}
	
	var dictionaryRepresentation: [String: AnyObject] {
		var result = [String: AnyObject]()
		result[MMRegionDataKeys.Latitude.rawValue] = center.latitude
		result[MMRegionDataKeys.Longitude.rawValue] = center.longitude
		result[MMRegionDataKeys.Radius.rawValue] = radius
		result[MMRegionDataKeys.Title.rawValue] = title
		result[MMRegionDataKeys.ExpiryDate.rawValue] = expiryDateString
		result[MMRegionDataKeys.Identifier.rawValue] = identifier
		
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