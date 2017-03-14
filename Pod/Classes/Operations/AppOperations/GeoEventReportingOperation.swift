//
//  GeoEventReportingOperation.swift
//
//  Created by Andrey K. on 21/10/2016.
//
//

import UIKit
import CoreData

class GeoEventReportingOperation: Operation {
    typealias CampaignId = String
    typealias CampaignsDictionary = [CampaignId: MMGeoMessage]
	typealias MessageId = String
	let context: NSManagedObjectContext
	let finishBlock: ((MMGeoEventReportingResult) -> Void)?
	var result = MMGeoEventReportingResult.Cancel
	var happenedEventObjectIds = [NSManagedObjectID]()
    var signalingGeoMessages = CampaignsDictionary()
	let mmContext: MobileMessaging
	
	init(context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: ((MMGeoEventReportingResult) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		self.mmContext = mmContext
	}
	
	override func execute() {
		context.perform {
            guard let internalId = self.mmContext.currentUser.internalId else
            {
                MMLogDebug("[Geo event reporting] installation object not found, finishing the operation...")
                self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
                return
            }
            
			guard let happenedEvents = GeoEventReportObject.MM_findAllInContext(self.context), !happenedEvents.isEmpty else
			{
				MMLogDebug("[Geo event reporting] There is no non-reported geo events to send to the server. Finishing...")
				self.finish()
				return
			}
			
			let geoEventReportsData = happenedEvents.flatMap { event -> GeoEventReportData? in
				guard let eventType = RegionEventType(rawValue: event.eventType) else {
					return nil
				}
				self.happenedEventObjectIds.append(event.objectID)
				return GeoEventReportData(geoAreaId: event.geoAreaId, eventType: eventType, campaignId: event.campaignId, eventDate: event.eventDate, sdkMessageId: event.sdkMessageId, messageId: event.messageId)
			}
			
            self.signalingGeoMessages = self.findGeoSignalingMessages(forHappenedEvents: happenedEvents)
            let originGeoMessagesValues = Array(self.signalingGeoMessages.values)
            
            if !originGeoMessagesValues.isEmpty, !geoEventReportsData.isEmpty {
                self.mmContext.remoteApiManager.sendGeoEventReports(internalId: internalId, eventsDataList: geoEventReportsData, geoMessages: originGeoMessagesValues) { result in
					self.result = result
					self.handleRequestResult(result)
					self.finishWithError(result.error)
				}
			} else {
				MMLogDebug("[Geo event reporting] There is no non-reported geo events to send to the server. Finishing...")
				self.finish()
			}
		}
	}
	
	private func findGeoSignalingMessages(forHappenedEvents happenedEvents: [GeoEventReportObject]) -> CampaignsDictionary {
        let campaignIds = Set(happenedEvents.map { $0.campaignId })
        let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "campaignId IN %@", campaignIds), context: context)
        return messages?.reduce(CampaignsDictionary(), { (result, messageObject) -> CampaignsDictionary in
            guard let campaigId = messageObject.campaignId else {
                return result
            }
            var result = result
            result[campaigId] = MMGeoMessage(managedObject: messageObject)
            return result
        }) ?? CampaignsDictionary()
	}
	
	private func handleRequestResult(_ result: MMGeoEventReportingResult) {
		context.performAndWait {
			let completionsGroup = DispatchGroup()
			var geoSignalingMessages = [MessageId: MMGeoMessage]()

			switch result {
			case .Success(let response):
				if let finishedCampaignIds = response.finishedCampaignIds, !finishedCampaignIds.isEmpty {
					completionsGroup.enter()
					self.mmContext.messageHandler.updateDbMessagesCampaignFinishedState(forCampaignIds:finishedCampaignIds, completion: {
						completionsGroup.leave()
					})
				}
				
				completionsGroup.enter()
				self.mmContext.messageHandler.updateSdkGeneratedTemporaryMessageIds(withMap: response.tempMessageIdRealMessageId, completion: {
					completionsGroup.leave()
				})
			default: break
			}
			
			let mtMessagesDatasource = GeoEventReportObject.MM_findAllWithPredicate(NSPredicate(format: "SELF IN %@", self.happenedEventObjectIds), context: self.context)?.reduce([MessageId: MMGeoMessage](), { (datasourceResult, event) -> [MessageId: MMGeoMessage] in
				
				guard let geoCampaign = self.signalingGeoMessages[event.campaignId] else {
					return datasourceResult
				}

				let ret: [MessageId: MMGeoMessage]
				
				switch result {
				case .Success(let response):
					MMLogDebug("[Geo event reporting] Geo event reporting request succeeded.")
					
					// we are about to generate a mt message only for active campaigns
					if let key = response.tempMessageIdRealMessageId[event.sdkMessageId], (response.finishedCampaignIds + response.suspendedCampaignIds).contains(event.campaignId) == false, event.messageShown == false
					{
						ret = datasourceResult + [key: geoCampaign]
						geoCampaign.onEventOccur(ofType: RegionEventType(rawValue: event.eventType) ?? .entry)
						geoSignalingMessages = geoSignalingMessages + [geoCampaign.messageId: geoCampaign]
					} else {
						ret = datasourceResult
					}
					self.context.delete(event)
					
				case .Failure(let error):
					MMLogError("[Geo event reporting] Geo event reporting request failed with error: \(error)")
					if event.messageShown == false {
						// if we had a failed request, we should generate a message for the campaign immediately regardless the campaign status
						// we'll use the sdk generated message id to generate a mt message with it further in `generateAndHandleGeoVirtualMessages`
						ret = datasourceResult + [event.sdkMessageId: geoCampaign]
						geoCampaign.onEventOccur(ofType: RegionEventType(rawValue: event.eventType) ?? .entry)
						geoSignalingMessages = geoSignalingMessages + [geoCampaign.messageId: geoCampaign]
						
						event.messageShown = true
					} else {
						ret = datasourceResult
					}
				default:
					ret = datasourceResult
				}
				
				return ret
			})
			
			self.context.MM_saveToPersistentStoreAndWait()
			
			if let mtMessagesDatasource = mtMessagesDatasource, !mtMessagesDatasource.isEmpty {
				
				completionsGroup.enter()
				MMLogDebug("[Geo event reporting] updating stored payloads...")
				self.mmContext.messageHandler.updateOiginalPayloadsWithGeoMessages(geoSignalingMessages: geoSignalingMessages, completion: {
					completionsGroup.leave()
				})
				
				completionsGroup.enter()
				MMLogDebug("[Geo event reporting] generating geo campaign messages...")
				self.mmContext.messageHandler.generateAndHandleGeoVirtualMessages(withDatasource: mtMessagesDatasource, completion: {
					completionsGroup.leave()
				})
			}
			
			completionsGroup.enter()
			MMLogDebug("[Geo event reporting] syncing seen status...")
			self.mmContext.messageHandler.syncSeenStatusUpdates({ _ in
				completionsGroup.leave()
			})
			completionsGroup.wait()
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
