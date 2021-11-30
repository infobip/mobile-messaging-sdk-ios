//
//  GeoEventPersistingOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 19.08.2020.
//

import Foundation
import CoreData

class GeoEventPersistingOperation : MMOperation {
	let context: NSManagedObjectContext
	let finishBlock: (Error?) -> Void
	let geoMessage: MMGeoMessage
	let eventType: RegionEventType
	let regionId: String

	init(geoMessage: MMGeoMessage, regionId: String, eventType: RegionEventType, context: NSManagedObjectContext, finishBlock: @escaping ((Error?) -> Void)) {
		self.geoMessage = geoMessage
		self.finishBlock = finishBlock
		self.context = context
		self.eventType = eventType
		self.regionId = regionId
		super.init(isUserInitiated: false)
	}

	override func execute() {
		guard !isCancelled else {
			logDebug("cancelled...")
			finish()
			return
		}
		logVerbose("started...")
		context.performAndWait {
			GeoEventReportObject.createEntity(withCampaignId: geoMessage.campaignId, eventType: self.eventType.rawValue, regionId: self.regionId, messageId: geoMessage.messageId, in: self.context)
			context.MM_saveToPersistentStoreAndWait()
		}
		finish()
	}

	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logVerbose("finished: \(errors)")
		finishBlock(errors.first)
	}
}
