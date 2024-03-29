//
//  GeoEventReportingOperation.swift
//
//  Created by Andrey K. on 21/10/2016.
//
//

import UIKit
import CoreData

class GeoEventReportingOperation: MMOperation {
	typealias CampaignId = String
	typealias CampaignsDictionary = [CampaignId: MMGeoMessage]
	typealias MessageId = String
	let context: NSManagedObjectContext
	let finishBlock: (GeoEventReportingResult) -> Void
	var result = GeoEventReportingResult.Cancel
	var happenedEventObjectIds = [NSManagedObjectID]()
	var signalingGeoMessages = CampaignsDictionary()
	let mmContext: MobileMessaging
	let geoContext: MMGeofencingService
	
	init(context: NSManagedObjectContext, mmContext: MobileMessaging, geoContext: MMGeofencingService, finishBlock: @escaping (GeoEventReportingResult) -> Void) {
		self.context = context
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		self.geoContext = geoContext
		super.init(isUserInitiated: false)
		self.addCondition(HealthyRegistrationCondition(mmContext: mmContext))
	}
	
	override func execute() {
		guard let internalId = mmContext.currentInstallation().pushRegistrationId else {
			logDebug("installation object not found, finishing the operation...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}

		context.perform {
			guard let happenedEvents = GeoEventReportObject.MM_findAllInContext(self.context), !happenedEvents.isEmpty else
			{
				self.logDebug("There is no non-reported geo events to send to the server. Finishing...")
				self.finish()
				return
			}
			
			let geoEventReportsData = happenedEvents.compactMap { event -> GeoEventReportData? in
				guard let eventType = RegionEventType(rawValue: event.eventType) else {
					return nil
				}
				self.happenedEventObjectIds.append(event.objectID)
				return GeoEventReportData(geoAreaId: event.geoAreaId, eventType: eventType, campaignId: event.campaignId, eventDate: event.eventDate, sdkMessageId: event.sdkMessageId, messageId: event.messageId)
			}
			
			self.signalingGeoMessages = self.findGeoSignalingMessages(forHappenedEvents: happenedEvents)
			let originGeoMessagesValues = Array(self.signalingGeoMessages.values)
			
			if !originGeoMessagesValues.isEmpty, !geoEventReportsData.isEmpty {
				self.logDebug("reporting started for \(geoEventReportsData.count) geo events from \(originGeoMessagesValues.count) campaigns.")

                self.geoContext.remoteApiProvider.reportGeoEvent(applicationCode: self.mmContext.applicationCode, pushRegistrationId: internalId, eventsDataList: geoEventReportsData, geoMessages: originGeoMessagesValues, queue: self.underlyingQueue, completion: { (result) in
					self.handleRequestResult(result) {
						self.finishWithError(result.error)
					}
				})
			} else {
				self.logDebug("There is no non-reported geo events to send to the server. Finishing...")
				self.finish()
			}
		}
	}
	
	private func findGeoSignalingMessages(forHappenedEvents happenedEvents: [GeoEventReportObject]) -> CampaignsDictionary {
		let campaignIds = Set(happenedEvents.map { $0.campaignId })
		let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageTypeValue == \(MMMessageType.Geo.rawValue) AND campaignId IN %@", campaignIds), context: context)
		return messages?.reduce(CampaignsDictionary(), { (result, messageObject) -> CampaignsDictionary in
			guard let campaigId = messageObject.campaignId else {
				return result
			}
			var result = result
			result[campaigId] = MMGeoMessage(managedObject: messageObject)
			return result
		}) ?? CampaignsDictionary()
	}
	
	typealias AreaId = String
	typealias MTMessagesDatasource = [MessageId: (MMGeoMessage, AreaId)]
	
	private func handleRequestResult(_ result: GeoEventReportingResult, completion: @escaping () -> Void) {
        assert(!Thread.isMainThread)
		self.result = result
		let messagesUpdatingGroup = DispatchGroup()
		switch result {
		case .Success(let response):
			if let finishedCampaignIds = response.finishedCampaignIds, !finishedCampaignIds.isEmpty {
				messagesUpdatingGroup.enter()
				self.mmContext.messageHandler.updateDbMessagesCampaignFinishedState(forCampaignIds:finishedCampaignIds, completion: {
					messagesUpdatingGroup.leave()
				})
			}
			
			messagesUpdatingGroup.enter()
			self.mmContext.messageHandler.updateSdkGeneratedTemporaryMessageIds(withMap: response.tempMessageIdRealMessageId, completion: {
				messagesUpdatingGroup.leave()
			})
		default: break
		}
		
		var changedSigMessages = [MessageId: MMGeoMessage]()
		var mtMessagesDatasource: MTMessagesDatasource?
		context.performAndWait {
			mtMessagesDatasource = GeoEventReportObject.MM_findAllWithPredicate(NSPredicate(format: "SELF IN %@", self.happenedEventObjectIds), context: self.context)?.reduce(MTMessagesDatasource(), { (datasourceResult, event) -> MTMessagesDatasource in
				guard let geoCampaign = self.signalingGeoMessages[event.campaignId] else {
                    return datasourceResult
				}
				
				let ret: MTMessagesDatasource
				
				let onEventOccur: (String) -> MTMessagesDatasource  = { messageId in
					geoCampaign.onEventOccur(ofType: RegionEventType(rawValue: event.eventType) ?? .entry)
					changedSigMessages += [geoCampaign.messageId: geoCampaign]
					return [messageId: (geoCampaign, event.geoAreaId)]
				}
				
				switch result {
				case .Success(let response):
					logDebug("Geo event reporting request succeeded.")
					// we are about to generate a mt message only for active campaigns
					if let key = response.tempMessageIdRealMessageId[event.sdkMessageId],
						   (response.finishedCampaignIds + response.suspendedCampaignIds).contains(event.campaignId) == false,
						   event.messageShown == false {
						ret = datasourceResult + onEventOccur(key)
					} else {
						ret = datasourceResult
					}
					self.context.delete(event)
					
				case .Failure(let error):
					logError("Geo event reporting request failed with error: \(error.orNil)")
					if event.messageShown == false {
						// if we had a failed request, we should generate a message for the campaign immediately regardless the campaign status
						// we'll use the sdk generated message id to generate a mt message with it further in `generateAndHandleGeoVirtualMessages`
						ret = datasourceResult + onEventOccur(event.sdkMessageId)
						event.messageShown = true
					} else {
						ret = datasourceResult
					}
				default: ret = datasourceResult
				}
				return ret
			})
			context.MM_saveToPersistentStoreAndWait()
		}
		
		messagesUpdatingGroup.notify(queue: DispatchQueue.global(qos: .default), execute: {
			let completionsGroup = DispatchGroup()
			if let mtMessagesDatasource = mtMessagesDatasource, !mtMessagesDatasource.isEmpty {
				completionsGroup.enter()
				self.logDebug("updating stored payloads...")
				self.mmContext.messageHandler.updateOriginalPayloadsWithMessages(messages: changedSigMessages) {
					self.logDebug("stopped updating stored payloads.")
					completionsGroup.leave()
				}
				
				completionsGroup.enter()
				self.logDebug("generating geo campaign messages...")
				self.generateMessages(mtMessagesDatasource) { _ in
					self.logDebug("stopped generating geo campaign messages.")
					completionsGroup.leave()
				}
			}
			
			completionsGroup.enter()
			self.logDebug("syncing seen status...")
            self.mmContext.messageHandler.syncSeenStatusUpdates(userInitiated: false, completion: { _ in
				self.logDebug("stopped syncing seen status.")
				completionsGroup.leave()
			})
			
			completionsGroup.notify(queue: DispatchQueue.global(qos: .default), execute: completion)
		})
	}

	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		if let error = errors.first {
			result = GeoEventReportingResult.Failure(error)
		}
		finishBlock(result)
	}
	
	//MARK: Utils
	func generateMessages(_ mtMessagesDatasource: MTMessagesDatasource, completion: @escaping (MessageHandlingResult) -> Void ) {
		let locallyGeneratedMessages = mtMessagesDatasource.reduce([MM_MTMessage]()) { (result, kv: (mId: MessageId, messageData: (campaign: MMGeoMessage, areaId: AreaId))) -> [MM_MTMessage] in
			if let region = kv.messageData.campaign.regions.filter({ return $0.identifier == kv.messageData.areaId }).first {
				if let mtMessage = MM_MTMessage.make(fromGeoMessage: kv.messageData.campaign, messageId: kv.mId, region: region) {
					return result + [mtMessage]
				}
			}
			return result
		}
        self.mmContext.messageHandler.handleMTMessages(userInitiated: false, messages: locallyGeneratedMessages, handlingIteration: 2, completion: completion)
	}
}
