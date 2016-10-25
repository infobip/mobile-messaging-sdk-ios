//
//  GeoEventPersistingOperation.swift
//
//  Created by Andrey K. on 21/10/2016.
//
//

import UIKit
import CoreData

class GeoEventPersistingOperation: Operation {
	let context: NSManagedObjectContext
	let finishBlock: (() -> Void)?
	let eventType: MMRegionEventType
	let regionId: String
	let message: MMGeoMessage
	
	init(message: MMGeoMessage, eventType: MMRegionEventType, regionId: String, context: NSManagedObjectContext, finishBlock: (() -> Void)? = nil) {
		self.message = message
		self.eventType = eventType
		self.regionId = regionId
		self.context = context
		self.finishBlock = finishBlock
	}
	
	override func execute() {
		context.performBlockAndWait {
			
			if let msg = MessageManagedObject.MM_findFirstInContext(NSPredicate(format: "messageId == %@", self.message.messageId), context: self.context),
				var payload = msg.payload,
				var internalData = payload[APNSPayloadKeys.kInternalData] as? [String: AnyObject]
			{
				internalData += [APNSPayloadKeys.kInternalDataGeo: self.message.regions.map{ $0.dictionaryRepresentation }]
				payload.updateValue(internalData, forKey: APNSPayloadKeys.kInternalData)
				msg.payload = payload
			}
			
			let newEvent = GeoEventReportObject.MM_createEntityInContext(context: self.context)
			newEvent.campaignId = self.message.campaignId
			newEvent.eventType = self.eventType.rawValue
			newEvent.eventDate = NSDate()
			newEvent.geoAreaId = self.regionId
			
			self.context.MM_saveToPersistentStoreAndWait()
		}
		MMLogDebug("[Geo event persisting] New geo event data persisted.")
		finish()
	}
	
	override func finished(errors: [NSError]) {
		finishBlock?()
	}
}


