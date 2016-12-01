//
//  GeoEventReportingOperation.swift
//
//  Created by Andrey K. on 21/10/2016.
//
//

import UIKit
import CoreData

class GeoEventReportingOperation: Operation {
	let context: NSManagedObjectContext
	let finishBlock: ((MMGeoEventReportingResult) -> Void)?
	var result = MMGeoEventReportingResult.Cancel
	var sentIds = [NSManagedObjectID]()
	
	init(context: NSManagedObjectContext, finishBlock: ((MMGeoEventReportingResult) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
	}
	
	override func execute() {
		self.context.perform {
			
			guard let happenedEvents = GeoEventReportObject.MM_findAllInContext(self.context), !happenedEvents.isEmpty
				else
			{
				MMLogDebug("[Geo event reporting] There is no non-reported geo events to send to the server. Finishing...")
				self.finish()
				return
			}
			
			let geoEventReportsData = happenedEvents.flatMap { event -> GeoEventReportData? in
				guard let eventType = MMRegionEventType(rawValue: event.eventType) else {
					return nil
				}
				self.sentIds.append(event.objectID)
				return GeoEventReportData(geoAreaId: event.geoAreaId, eventType: eventType, campaignId: event.campaignId, eventDate: event.eventDate, messageId: event.messageId)
			}
			
			if !geoEventReportsData.isEmpty {
				MobileMessaging.sharedInstance?.remoteApiManager.sendGeoEventReports(eventsDataList: geoEventReportsData) { result in
					self.handleRequestResult(result)
					self.finishWithError(result.error)
				}
			} else {
				MMLogDebug("[Geo event reporting] There is no non-reported geo events to send to the server. Finishing...")
				self.finish()
			}
		}
	}
	
	private func handleRequestResult(_ result: MMGeoEventReportingResult) {
		self.result = result
		switch result {
		case .Success(let response):
			MMLogError("[Geo event reporting] Geo event reporting request succeeded.")
			context.performAndWait {
				if let campaignIds = response.finishedCampaignIds {
					self.setPersistedCampaignsState(.Finished, for: campaignIds)
				}
				if let happenedEvents = GeoEventReportObject.MM_findAllWithPredicate(NSPredicate(format: "SELF IN %@", self.sentIds), context: self.context), !happenedEvents.isEmpty {
					happenedEvents.forEach { event in
						self.context.delete(event)
					}
				}
				self.context.MM_saveToPersistentStoreAndWait()
			}
		case .Failure(let error):
			MMLogError("[Geo event reporting] Geo event reporting request failed with error: \(error)")
		case .Cancel: break
		}
	}
	
	private func setPersistedCampaignsState(_ state: CampaignState, for campaignIds: [String]) {
		let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "campaignId IN %@", campaignIds), context: self.context)
		messages?.forEach { messageObj in
			messageObj.campaignState = state
		}
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Geo event reporting] finished with errors: \(errors)")
		if let error = errors.first {
			result = MMGeoEventReportingResult.Failure(error)
		}
		finishBlock?(result)
	}
}
