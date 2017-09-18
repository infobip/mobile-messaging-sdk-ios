//
//  GeoMessage.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation
import CoreData

struct CampaignDataKeys {
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

struct RegionDataKeys {
	static let latitude = "latitude"
	static let longitude = "longitude"
	static let radius = "radiusInMeters"
	static let title = "title"
	static let identifier = "id"
}

struct RegionDeliveryTimeKeys {
	static let days = "days"
	static let timeInterval = "timeInterval"
}

struct RegionEventDataKeys {
	static let eventType = "type"
	static let eventLimit = "limit"
	static let eventTimeout = "timeoutInMinutes"
	static let occuringCounter = "rate"
	static let eventLastOccur = "lastOccur"
}

enum RegionEventType: String {
	case entry
	case exit
}

final public class MMGeoMessage: MTMessage {
	public let campaignId: String
	public let regions: Set<MMRegion>
	public let startTime: Date
	public let expiryTime: Date
	public var isNotExpired: Bool {
		return GeofencingService.isGeoCampaignNotExpired(campaign: self)
	}
	
	var hasValidEventsStateForNow: Bool {
		return events.filter({ $0.isValidNow }).isEmpty == false
	}
	
	var hasValidEventsStateInGeneral: Bool {
		return events.filter({ $0.isValidInGeneral }).isEmpty == false
	}
	
	public var campaignState: CampaignState = .Active
	
	convenience init?(managedObject: MessageManagedObject) {
		guard let payload = managedObject.payload else {
			return nil
		}
		
		self.init(payload: payload)
		self.campaignState = managedObject.campaignState
	}
	
	func onEventOccur(ofType eventType: RegionEventType) {
		events.filter { $0.type == eventType }.first?.occur()
		if var internalData = originalPayload[APNSPayloadKeys.internalData] as? DictionaryRepresentation {
			internalData += [InternalDataKeys.event: events.map { $0.dictionaryRepresentation }]
			originalPayload.updateValue(internalData, forKey: APNSPayloadKeys.internalData)
		}
	}
	
	public override init?(payload: APNSPayload) {
		guard
			let internalData = payload[APNSPayloadKeys.internalData] as? StringKeyPayload,
			let geoRegionsData = internalData[InternalDataKeys.geo] as? [StringKeyPayload],
			let expiryTimeString = internalData[CampaignDataKeys.expiryDate] as? String,
			let startTimeString = internalData[CampaignDataKeys.startDate] as? String ?? DateStaticFormatters.ISO8601SecondsFormatter.string(from: MobileMessaging.date.timeInterval(sinceReferenceDate: 0)) as String?,
			let expiryTime = DateStaticFormatters.ISO8601SecondsFormatter.date(from: expiryTimeString),
			let startTime = DateStaticFormatters.ISO8601SecondsFormatter.date(from: startTimeString),
			let campaignId = internalData[CampaignDataKeys.campaignId] as? String
			else
		{
			return nil
		}
		self.campaignId = campaignId
		self.expiryTime = expiryTime
		self.startTime = startTime
		
		let deliveryTime: DeliveryTime?
		if let deliveryTimeDict = internalData[InternalDataKeys.deliveryTime] as? DictionaryRepresentation {
			deliveryTime = DeliveryTime(dictRepresentation: deliveryTimeDict)
		} else {
			deliveryTime = nil
		}
		
		let evs: [RegionEvent]
		if let eventDicts = internalData[InternalDataKeys.event] as? [DictionaryRepresentation] {
			evs = eventDicts.flatMap { return RegionEvent(dictRepresentation: $0) }
		} else {
			evs = [RegionEvent.defaultEvent]
		}
		
		self.deliveryTime = deliveryTime
		self.events = evs
		self.regions = Set(geoRegionsData.flatMap(MMRegion.init))
		super.init(payload: payload)
		self.regions.forEach({ $0.message = self })
	}
	
	public var isNowAppropriateTimeForEntryNotification: Bool {
		return isNowAppropriateTimeForNotification(for: .entry)
	}
	
	public var isNowAppropriateTimeForExitNotification: Bool {
		return isNowAppropriateTimeForNotification(for: .exit)
	}
	
	//MARK: - Internal
	let deliveryTime: DeliveryTime?
	
	func isLiveNow(for type: RegionEventType) -> Bool {
		guard events.contains(where: {$0.type == type}) else {
			return false
		}
		let containsAnInvalidEvent = events.contains(where: {$0.isValidNow == false && $0.type == type})
		return !containsAnInvalidEvent && isNotExpired
	}
	
	func isNowAppropriateTimeForNotification(for type: RegionEventType) -> Bool {
		let now = GeofencingService.currentDate ?? MobileMessaging.date.now
		return deliveryTime?.isNow ?? true && isLiveNow(for: type) && now.compare(startTime) != .orderedAscending
	}
	
	let events: [RegionEvent]
    
    var geoEventReportFormat: StringKeyPayload {
        var geoEventReportFormat: [String: Any] = ["messageId": messageId,
                                                   "body": text ?? "",
                                                   "silent": isSilent,
                                                   "alert": text ?? ""]
        
        geoEventReportFormat["badge"] = aps.badge
        geoEventReportFormat["sound"] = sound
        geoEventReportFormat["title"] = nil
        
        if let customPayload = customPayload, !customPayload.isEmpty {
            let json = JSON(customPayload)
            geoEventReportFormat["customPayload"] = json.stringValue
        }
        
        if let internalData = internalData, !internalData.isEmpty {
            let json = JSON(internalData)
            geoEventReportFormat["internalData"] = json.stringValue
        }
        
        return geoEventReportFormat
    }
}

public class DeliveryTime: NSObject, DictionaryRepresentable {
	public let timeInterval: DeliveryTimeInterval?
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
		return GeofencingService.isNowAppropriateDay(forDeliveryTime: self)
	}
	
	required public convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		let interval = DeliveryTimeInterval(dictRepresentation: dict)
		let days: Set<MMDay>?

		if let daysArray = (dict[RegionDeliveryTimeKeys.days] as? String)?.components(separatedBy: ",") {
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
			result[RegionDeliveryTimeKeys.days] = Array(days).flatMap({ String($0.rawValue) }).joined(separator: ",")
		}
		assert(DeliveryTime(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	init(timeInterval: DeliveryTimeInterval?, days: Set<MMDay>?) {
		self.timeInterval = timeInterval
		self.days = days
	}
	
	var currentTestDate: Date? // dependency for testing purposes
}

@objc public enum MMDay: Int8 {
	case mo = 1, tu = 2, we = 3, th = 4, fr = 5, sa = 6, su = 7
}

public class DeliveryTimeInterval: NSObject, DictionaryRepresentable {
	static let timeIntervalSeparator = "/"
	let fromTime: String
	let toTime: String
	
	init(fromTime: String, toTime: String) {
		self.fromTime = fromTime
		self.toTime = toTime
	}
	
	var isNow: Bool {
		return GeofencingService.isNowAppropriateTime(forDeliveryTimeInterval: self)
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
		if let comps = (dict[RegionDeliveryTimeKeys.timeInterval] as? String)?.components(separatedBy: DeliveryTimeInterval.timeIntervalSeparator),
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
		result[RegionDeliveryTimeKeys.timeInterval] = "\(fromTime)\(DeliveryTimeInterval.timeIntervalSeparator)\(toTime)"
		assert(DeliveryTimeInterval(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
}

final public class MMRegion: NSObject, DictionaryRepresentable {
	public let identifier: String
	var dataSourceIdentifier: String {
		return "\((message?.campaignId) ?? "")_\(identifier)"
	}
	public let center: CLLocationCoordinate2D
	public let radius: Double
	public let title: String
	weak var message: MMGeoMessage?
	
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
		return "id \(dataSourceIdentifier), \(title), radius \(radius)m: \(center.longitude) \(center.latitude)"
	}
	
	public convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		guard
			let lat = dict[RegionDataKeys.latitude] as? Double,
			let lon = dict[RegionDataKeys.longitude] as? Double,
			let title = dict[RegionDataKeys.title] as? String,
			let identifier = dict[RegionDataKeys.identifier] as? String,
			let radius = dict[RegionDataKeys.radius] as? Double
			else
		{
			return nil
		}

		self.init(identifier: identifier, center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: radius, title: title)
	}
	
	public var dictionaryRepresentation: DictionaryRepresentation {
		var result = DictionaryRepresentation()
		result[RegionDataKeys.latitude] = center.latitude
		result[RegionDataKeys.longitude] = center.longitude
		result[RegionDataKeys.radius] = radius
		result[RegionDataKeys.title] = title
		result[RegionDataKeys.identifier] = identifier
		assert(MMRegion(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	public override var hashValue: Int {
		return dataSourceIdentifier.hashValue
	}
	
	public override var hash: Int {
		return dataSourceIdentifier.hash
	}
	
	public override func isEqual(_ object: Any?) -> Bool {
		guard let obj = object as? MMRegion else {
			return false
		}
		return obj.dataSourceIdentifier == self.dataSourceIdentifier
	}
}

final class RegionEvent: DictionaryRepresentable, CustomStringConvertible {
	let type: RegionEventType
	let limit: Int					//how many times this event can occur, 0 means unlimited
	let timeout: Int			    //minutes till next possible event
	var occuringCounter: Int = 0
	var lastOccuring: Date?
	
	var hasReachedTheOccuringLimit: Bool {
		return limit != 0 && occuringCounter >= limit
	}
	
	var description: String {
		return "type:\(type), limit: \(limit), timeout: \(timeout), occuringCounter: \(occuringCounter), lastOccuring: \(String(describing: lastOccuring)), isValidNow: \(isValidNow), isValidInGeneral: \(isValidInGeneral)"
	}
	
	var isValidNow: Bool {
		return GeofencingService.isRegionEventValidNow(self)
	}
	
	var isValidInGeneral: Bool {
		return GeofencingService.isRegionEventValidInGeneral(self)
	}
	
	fileprivate func occur() {
		occuringCounter += 1
		lastOccuring = MobileMessaging.date.now
	}

	init?(dictRepresentation dict: DictionaryRepresentation) {
		guard
			let typeString = dict[RegionEventDataKeys.eventType] as? String,
			let type = RegionEventType(rawValue: typeString),
			let limit = dict[RegionEventDataKeys.eventLimit] as? Int
			else
		{
			return nil
		}
		self.type = type
		self.limit = limit
		self.timeout = dict[RegionEventDataKeys.eventTimeout] as? Int ?? 0
		self.occuringCounter = dict[RegionEventDataKeys.occuringCounter] as? Int ?? 0
		self.lastOccuring = dict[RegionEventDataKeys.eventLastOccur] as? Date ?? nil
	}
	
	var dictionaryRepresentation: DictionaryRepresentation {
		var result = DictionaryRepresentation()
		result[RegionEventDataKeys.eventType] = type.rawValue
		result[RegionEventDataKeys.eventLimit] = limit
		result[RegionEventDataKeys.eventTimeout] = timeout
		result[RegionEventDataKeys.occuringCounter] = occuringCounter
		result[RegionEventDataKeys.eventLastOccur] = lastOccuring
		assert(RegionEvent(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}

	fileprivate class var defaultEvent: RegionEvent {
		let defaultDict: DictionaryRepresentation = [RegionEventDataKeys.eventType: RegionEventType.entry.rawValue,
		                                             RegionEventDataKeys.eventLimit: 1,
		                                             RegionEventDataKeys.eventTimeout: 0]
		return RegionEvent(dictRepresentation: defaultDict)!
	}
}

extension MTMessage {
	static func make(fromGeoMessage geoMessage: MMGeoMessage, messageId: String, region: MMRegion) -> MTMessage? {
		guard let aps = geoMessage.originalPayload[APNSPayloadKeys.aps] as? [String: Any], let internalData = geoMessage.originalPayload[APNSPayloadKeys.internalData] as? [String: Any], var silentAps = internalData[InternalDataKeys.silent] as? [String: Any], let body = silentAps[APNSPayloadKeys.body] as? String else
		{
			return nil
		}
		
		silentAps[APNSPayloadKeys.alert] = [APNSPayloadKeys.body: body]
		silentAps[APNSPayloadKeys.body] = nil
		let apsConcat = aps + silentAps
		var newInternalData: [String: Any] = [InternalDataKeys.geo: [region.dictionaryRepresentation]]
		newInternalData["atts"] = geoMessage.internalData?["atts"]
		
		var newpayload = geoMessage.originalPayload
		newpayload[APNSPayloadKeys.aps] = apsConcat
		newpayload[APNSPayloadKeys.internalData] = newInternalData
		newpayload[APNSPayloadKeys.messageId] = messageId
		
		//cut silent:true in case of fetched message
		newpayload.removeValue(forKey: InternalDataKeys.silent)
		
		let result = MTMessage(payload: newpayload)
		result?.deliveryMethod = .generatedLocally
		result?.isDeliveryReportSent = true
		return result
	}
}
