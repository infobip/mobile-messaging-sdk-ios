//
//  GeoMessage.swift
//
//  Created by Ivan Cigic on 06/07/16.
//
//

import Foundation
import CoreLocation
import CoreData

enum RegionEventType: String {
	case entry
	case exit
}

final public class MMGeoMessage: MM_MTMessage {
	public let campaignId: String
	public let regions: Set<MMRegion>
	public let startTime: Date
	public let expiryTime: Date
	public var isNotExpired: Bool {
		return MMGeofencingService.isGeoCampaignNotExpired(campaign: self)
	}
	
	var hasValidEventsStateInGeneral: Bool {
		return events.filter({ $0.isValidInGeneral }).isEmpty == false
	}
	
	public var campaignState: MMCampaignState = .Active
	
	convenience init?(managedObject: MessageManagedObject) {
		guard let payload = managedObject.payload else {
			return nil
		}
		
		self.init(payload: payload,
				  deliveryMethod: MMMessageDeliveryMethod(rawValue: managedObject.deliveryMethod) ?? .undefined,
				  seenDate: managedObject.seenDate,
				  deliveryReportDate: managedObject.deliveryReportedDate,
				  seenStatus: managedObject.seenStatus,
				  isDeliveryReportSent: managedObject.reportSent)
		self.campaignState = managedObject.campaignState
	}
	
	func onEventOccur(ofType eventType: RegionEventType) {
		events.filter { $0.type == eventType }.first?.occur()
		if var internalData = originalPayload[Consts.APNSPayloadKeys.internalData] as? DictionaryRepresentation {
			internalData += [Consts.InternalDataKeys.event: events.map { $0.dictionaryRepresentation }]
			originalPayload.updateValue(internalData, forKey: Consts.APNSPayloadKeys.internalData)
		}
	}
	
	override public init?(payload: MMAPNSPayload, deliveryMethod: MMMessageDeliveryMethod, seenDate: Date?, deliveryReportDate: Date?, seenStatus: MMSeenStatus, isDeliveryReportSent: Bool)
	{
		guard
			let internalData = payload[Consts.APNSPayloadKeys.internalData] as? MMStringKeyPayload,
			let geoRegionsData = internalData[Consts.InternalDataKeys.geo] as? [MMStringKeyPayload],
			let expiryTimeString = internalData[GeoConstants.CampaignKeys.expiryDate] as? String,
			let startTimeString = internalData[GeoConstants.CampaignKeys.startDate] as? String ?? DateStaticFormatters.ISO8601SecondsFormatter.string(from: MobileMessaging.date.timeInterval(sinceReferenceDate: 0)) as String?,
			let expiryTime = DateStaticFormatters.ISO8601SecondsFormatter.date(from: expiryTimeString),
			let startTime = DateStaticFormatters.ISO8601SecondsFormatter.date(from: startTimeString),
			let campaignId = internalData[GeoConstants.CampaignKeys.campaignId] as? String
			else
		{
			return nil
		}
		self.campaignId = campaignId
		self.expiryTime = expiryTime
		self.startTime = startTime
		
		let deliveryTime: MMDeliveryTime?
		if let deliveryTimeDict = internalData[Consts.InternalDataKeys.deliveryTime] as? DictionaryRepresentation {
			deliveryTime = MMDeliveryTime(dictRepresentation: deliveryTimeDict)
		} else {
			deliveryTime = nil
		}
		
		let evs: [RegionEvent]
		if let eventDicts = internalData[Consts.InternalDataKeys.event] as? [DictionaryRepresentation] {
			evs = eventDicts.compactMap { return RegionEvent(dictRepresentation: $0) }
		} else {
			evs = [RegionEvent.defaultEvent]
		}
		
		self.deliveryTime = deliveryTime
		self.events = evs
		self.regions = Set(geoRegionsData.compactMap(MMRegion.init))
		super.init(payload: payload, deliveryMethod: deliveryMethod, seenDate: seenDate, deliveryReportDate: deliveryReportDate, seenStatus: seenStatus, isDeliveryReportSent: isDeliveryReportSent)
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
	
	func isLiveNow(for type: RegionEventType) -> Bool {
		guard events.contains(where: {$0.type == type}) else {
			return false
		}
		let containsAnInvalidEvent = events.contains(where: {$0.isValidNow == false && $0.type == type})
		return !containsAnInvalidEvent && isNotExpired
	}
	
	func isNowAppropriateTimeForNotification(for type: RegionEventType) -> Bool {
		let now = MMGeofencingService.currentDate ?? MobileMessaging.date.now
		let isDeliveryTimeNow = deliveryTime?.isNow ?? true
		let isCampaignNotExpired = isLiveNow(for: type)
		let isCampaignStarted = now.compare(startTime) != .orderedAscending
		return isDeliveryTimeNow && isCampaignNotExpired && isCampaignStarted
	}
	
	let events: [RegionEvent]
    
    var geoEventReportFormat: MMStringKeyPayload {
        var geoEventReportFormat: [String: Any] = ["messageId": messageId,
                                                   "body": text ?? "",
                                                   "silent": isSilent,
                                                   "alert": text ?? ""]
        
        geoEventReportFormat["badge"] = badge
        geoEventReportFormat["sound"] = sound
        geoEventReportFormat["title"] = title
        
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

@objcMembers
public class MMDeliveryTime: NSObject, DictionaryRepresentable {
	public let timeInterval: MMDeliveryTimeInterval?
	public let days: Set<MMDay>?
	var isNow: Bool {
		let time = isNowAppropriateTime
		let day = isNowAppropriateDay
		return time && day
	}
	
	private var isNowAppropriateTime: Bool {
		guard let timeInterval = timeInterval else {
			return true
		}
		return timeInterval.isNow
	}
	
	private var isNowAppropriateDay: Bool {
		return MMGeofencingService.isNowAppropriateDay(forDeliveryTime: self)
	}
	
	required public convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		let interval = MMDeliveryTimeInterval(dictRepresentation: dict)
		let days: Set<MMDay>?

		if let daysArray = (dict[GeoConstants.RegionDeliveryTimeKeys.days] as? String)?.components(separatedBy: ",") {
			days = Set(daysArray.compactMap ({ (dayNumString) -> MMDay? in
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
			result[GeoConstants.RegionDeliveryTimeKeys.days] = Array(days).compactMap({ String($0.rawValue) }).joined(separator: ",")
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

@objcMembers
public class MMDeliveryTimeInterval: NSObject, DictionaryRepresentable {
	static let timeIntervalSeparator = "/"
	let fromTime: String
	let toTime: String
	
	init(fromTime: String, toTime: String) {
		self.fromTime = fromTime
		self.toTime = toTime
	}
	
	var isNow: Bool {
		return MMGeofencingService.isNowAppropriateTime(forDeliveryTimeInterval: self)
	}
	
	/// Checks if `time` is in the interval defined with two time strings `fromTime` and `toTime` in ISO 8601 formats: `hhmm`
	class func isTime(_ time: Date, between fromTime: String, and toTime: String) -> Bool {
		let calendar = MobileMessaging.calendar
		let nowComps = calendar.dateComponents(in: MobileMessaging.timeZone, from: time)
		if let nowH = nowComps.hour, let nowM = nowComps.minute {
			let fromTimeMinutesIdx = fromTime.index(fromTime.startIndex, offsetBy: 2)
			let toTimeMinutesIdx = toTime.index(toTime.startIndex, offsetBy: 2)
			guard let fromH = Int(fromTime[fromTime.startIndex..<fromTimeMinutesIdx]),
				let fromM = Int(fromTime[fromTimeMinutesIdx..<fromTime.endIndex]),
				let toH = Int(toTime[toTime.startIndex..<toTimeMinutesIdx]),
				let toM = Int(toTime[toTimeMinutesIdx..<toTime.endIndex]) else
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
		if let comps = (dict[GeoConstants.RegionDeliveryTimeKeys.timeInterval] as? String)?.components(separatedBy: MMDeliveryTimeInterval.timeIntervalSeparator),
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
		result[GeoConstants.RegionDeliveryTimeKeys.timeInterval] = "\(fromTime)\(MMDeliveryTimeInterval.timeIntervalSeparator)\(toTime)"
		assert(MMDeliveryTimeInterval(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
}

@objcMembers
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
			let lat = dict[GeoConstants.RegionKeys.latitude] as? Double,
			let lon = dict[GeoConstants.RegionKeys.longitude] as? Double,
			let title = dict[GeoConstants.RegionKeys.title] as? String,
			let identifier = dict[GeoConstants.RegionKeys.identifier] as? String,
			let radius = dict[GeoConstants.RegionKeys.radius] as? Double
			else
		{
			return nil
		}

		self.init(identifier: identifier, center: CLLocationCoordinate2D(latitude: lat, longitude: lon), radius: radius, title: title)
	}
	
	public var dictionaryRepresentation: DictionaryRepresentation {
		var result = DictionaryRepresentation()
		result[GeoConstants.RegionKeys.latitude] = center.latitude
		result[GeoConstants.RegionKeys.longitude] = center.longitude
		result[GeoConstants.RegionKeys.radius] = radius
		result[GeoConstants.RegionKeys.title] = title
		result[GeoConstants.RegionKeys.identifier] = identifier
		assert(MMRegion(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}
	
	public override var hash: Int {
		return dataSourceIdentifier.hashValue
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
		return "type:\(type), limit: \(limit), timeout: \(timeout), occuringCounter: \(occuringCounter), lastOccuring: \(lastOccuring.orNil), isValidNow: \(isValidNow), isValidInGeneral: \(isValidInGeneral)"
	}
	
	var isValidNow: Bool {
		return MMGeofencingService.isRegionEventValidNow(self)
	}
	
	var isValidInGeneral: Bool {
		return MMGeofencingService.isRegionEventValidInGeneral(self)
	}
	
	fileprivate func occur() {
		occuringCounter += 1
		lastOccuring = MobileMessaging.date.now
	}

	init?(dictRepresentation dict: DictionaryRepresentation) {
		guard
			let typeString = dict[GeoConstants.RegionEventKeys.type] as? String,
			let type = RegionEventType(rawValue: typeString),
			let limit = dict[GeoConstants.RegionEventKeys.limit] as? Int
			else
		{
			return nil
		}
		self.type = type
		self.limit = limit
		self.timeout = dict[GeoConstants.RegionEventKeys.timeout] as? Int ?? 0
		self.occuringCounter = dict[GeoConstants.RegionEventKeys.occuringCounter] as? Int ?? 0
		self.lastOccuring = dict[GeoConstants.RegionEventKeys.lastOccur] as? Date ?? nil
	}
	
	var dictionaryRepresentation: DictionaryRepresentation {
		var result = DictionaryRepresentation()
		result[GeoConstants.RegionEventKeys.type] = type.rawValue
		result[GeoConstants.RegionEventKeys.limit] = limit
		result[GeoConstants.RegionEventKeys.timeout] = timeout
		result[GeoConstants.RegionEventKeys.occuringCounter] = occuringCounter
		result[GeoConstants.RegionEventKeys.lastOccur] = lastOccuring
		assert(RegionEvent(dictRepresentation: result) != nil, "The dictionary representation is invalid")
		return result
	}

	fileprivate class var defaultEvent: RegionEvent {
		let defaultDict: DictionaryRepresentation = [GeoConstants.RegionEventKeys.type: RegionEventType.entry.rawValue,
		                                             GeoConstants.RegionEventKeys.limit: 1,
		                                             GeoConstants.RegionEventKeys.timeout: 0]
		return RegionEvent(dictRepresentation: defaultDict)!
	}
}

extension MM_MTMessage {
	static func make(fromGeoMessage geoMessage: MMGeoMessage, messageId: String, region: MMRegion) -> MM_MTMessage? {
		guard let aps = geoMessage.originalPayload[Consts.APNSPayloadKeys.aps] as? [String: Any],
			let internalData = geoMessage.originalPayload[Consts.APNSPayloadKeys.internalData] as? [String: Any],
			let silentAps = internalData[Consts.InternalDataKeys.silent] as? [String: Any] else
		{
			return nil
		}
        
		var newInternalData: [String: Any] = [Consts.InternalDataKeys.geo: [region.dictionaryRepresentation]]
		newInternalData[Consts.InternalDataKeys.attachments] = geoMessage.internalData?[Consts.InternalDataKeys.attachments]
		newInternalData[Consts.InternalDataKeys.showInApp] = geoMessage.internalData?[Consts.InternalDataKeys.showInApp]
		newInternalData[Consts.InternalDataKeys.inAppStyle] = geoMessage.internalData?[Consts.InternalDataKeys.inAppStyle]
        newInternalData[Consts.InternalDataKeys.inAppDismissTitle] = geoMessage.internalData?[Consts.InternalDataKeys.inAppDismissTitle]
        newInternalData[Consts.InternalDataKeys.inAppOpenTitle] = geoMessage.internalData?[Consts.InternalDataKeys.inAppOpenTitle]
        newInternalData[Consts.InternalDataKeys.inAppExpiryDateTime] = geoMessage.internalData?[Consts.InternalDataKeys.inAppExpiryDateTime]
        newInternalData[Consts.InternalDataKeys.webViewUrl] = geoMessage.internalData?[Consts.InternalDataKeys.webViewUrl]
        newInternalData[Consts.InternalDataKeys.browserUrl] = geoMessage.internalData?[Consts.InternalDataKeys.browserUrl]
        newInternalData[Consts.InternalDataKeys.deeplink] = geoMessage.internalData?[Consts.InternalDataKeys.deeplink]
		
		var newpayload = geoMessage.originalPayload
		newpayload[Consts.APNSPayloadKeys.aps] = apsByMerging(nativeAPS: aps, withSilentAPS: silentAps)
		newpayload[Consts.APNSPayloadKeys.internalData] = newInternalData
		newpayload[Consts.APNSPayloadKeys.messageId] = messageId
		
		//cut silent:true in case of fetched message
		newpayload.removeValue(forKey: Consts.InternalDataKeys.silent)
		
		let result = MM_MTMessage(payload: newpayload,
							   deliveryMethod: .generatedLocally,
							   seenDate: nil,
							   deliveryReportDate: nil,
							   seenStatus: .NotSeen,
							   isDeliveryReportSent: true)
		return result
	}
}
