//
//  GeoEventReportObject.swift
//  
//
//  Created by Andrey K. on 21/10/2016.
//
//

import Foundation
import CoreData

@objc(GeoEventReportObject)
final public class GeoEventReportObject: NSManagedObject, FetchableResult {

// Insert code here to add functionality to your managed object subclass
	@discardableResult
	public class func createEntity(withCampaignId campaignId: String, eventType: String, regionId: String, messageId: String, in context: NSManagedObjectContext) -> GeoEventReportObject {
		let newEvent = GeoEventReportObject.MM_createEntityInContext(context: context)
		newEvent.campaignId = campaignId
		newEvent.eventType = eventType
		newEvent.eventDate = MobileMessaging.date.now
		newEvent.geoAreaId = regionId
		newEvent.messageId = messageId
		newEvent.sdkMessageId = UUID().uuidString
		return newEvent
	}
}
