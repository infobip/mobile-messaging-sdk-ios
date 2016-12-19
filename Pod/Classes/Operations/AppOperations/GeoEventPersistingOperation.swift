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
		self.context.performAndWait {
			
			if let msg = MessageManagedObject.MM_findFirstWithPredicate(NSPredicate(format: "messageId == %@", self.message.messageId), context: self.context),
				var payload = msg.payload,
				var internalData = payload[APNSPayloadKeys.kInternalData] as? DictionaryRepresentation
			{
				internalData += [APNSPayloadKeys.kInternalDataGeo: self.message.regions.map{ $0.dictionaryRepresentation }]
				internalData += [APNSPayloadKeys.kInternalDataEvent: self.message.events.map{ $0.dictionaryRepresentation}]
				payload.updateValue(internalData, forKey: APNSPayloadKeys.kInternalData)
				msg.payload = payload
			}
			
			let _ = GeoEventReportObject.createEntity(withCampaignId: self.message.campaignId, eventType: self.eventType.rawValue, regionId: self.regionId, messageId: self.message.messageId, in: self.context)
			self.context.MM_saveToPersistentStoreAndWait()
		}
		MMLogDebug("[Geo event persisting] New geo event data persisted.")
		finish()
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Geo event persisting] finished with errors \(errors).")
		finishBlock?()
	}
}
