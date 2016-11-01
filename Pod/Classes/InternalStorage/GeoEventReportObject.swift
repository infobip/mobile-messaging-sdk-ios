//
//  GeoEventReportObject.swift
//  
//
//  Created by Andrey K. on 21/10/2016.
//
//

import Foundation
import CoreData

class GeoEventReportObject: NSManagedObject {
	class func createEntity(withCampaignId campaignId: String, eventType: String, regionId: String, messageId: String, in context: NSManagedObjectContext) -> GeoEventReportObject {
		let newEvent = GeoEventReportObject.MM_createEntityInContext(context: context)
		newEvent.campaignId = campaignId
		newEvent.eventType = eventType
		newEvent.eventDate = NSDate()
		newEvent.geoAreaId = regionId
		newEvent.messageId = messageId
		return newEvent
	}
}
