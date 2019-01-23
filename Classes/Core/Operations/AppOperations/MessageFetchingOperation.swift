//
//  MessageFetchingOperation.swift
//
//  Created by Andrey K. on 20/06/16.
//

import Foundation
import CoreData

final class MessageFetchingOperation: Operation {
	
	let context: NSManagedObjectContext
	let finishBlock: ((MessagesSyncResult) -> Void)?
	var result = MessagesSyncResult.Cancel
	let mmContext: MobileMessaging
	let handlingIteration: Int
	
	init(context: NSManagedObjectContext, mmContext: MobileMessaging, handlingIteration: Int = 0, finishBlock: ((MessagesSyncResult) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		self.handlingIteration = handlingIteration
		super.init()
	}
	
	override func execute() {
		guard !isCancelled else {
			MMLogDebug("[Message fetching] cancelled...")
			finish()
			return
		}
		MMLogDebug("[Message fetching] Starting operation...")
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogWarn("[Message fetching] Registration is not healthy. Finishing...")
			result = MessagesSyncResult.Failure(NSError(type: MMInternalErrorType.InvalidRegistration))
			finish()
			return
		}
		syncMessages()
	}
	
	let messageTypesFilter = [MMMessageType.Default.rawValue, MMMessageType.Geo.rawValue]
	
	fileprivate func getArchiveMessageIds() -> [String]? {
		let date = MobileMessaging.date.timeInterval(sinceNow: -60 * 60 * 24 * Consts.MessageFetchingSettings.messageArchiveLengthDays)
		return MessageManagedObject.MM_find(withPredicate: NSPredicate(format: "reportSent == true AND creationDate > %@ AND messageTypeValue IN %@", date as CVarArg, messageTypesFilter), fetchLimit: Consts.MessageFetchingSettings.fetchLimit, sortedBy: "creationDate", ascending: false, inContext: self.context)?.map{ $0.messageId }
	}
	
	fileprivate func getNonReportedMessageIds() -> [String]? {
		return MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "reportSent == false AND messageTypeValue IN %@", messageTypesFilter), context: self.context)?.map{ $0.messageId }
	}
	
	private func syncMessages() {
		guard let pushRegistrationId = mmContext.currentInstallation.pushRegistrationId else {
			MMLogWarn("[Message fetching] No registration. Finishing...")
			result = MessagesSyncResult.Failure(NSError(type: MMInternalErrorType.NoRegistration))
			finish()
			return
		}

		context.performAndWait {
			context.reset()
			
			let nonReportedMessageIds = self.getNonReportedMessageIds()
			let archveMessageIds = self.getArchiveMessageIds()
			
			MMLogDebug("[Message fetching] Found \(String(describing: nonReportedMessageIds?.count)) not reported messages. \(String(describing: archveMessageIds?.count)) archive messages.")
			
			self.mmContext.remoteApiProvider.syncMessages(applicationCode: self.mmContext.applicationCode, pushRegistrationId: pushRegistrationId, archiveMsgIds: archveMessageIds, dlrMsgIds: nonReportedMessageIds) { result in
				self.result = result
				self.handleRequestResponse(result: result, nonReportedMessageIds: nonReportedMessageIds) {
					self.finish()
				}
			}
		}
	}
	
	private func handleRequestResponse(result: MessagesSyncResult, nonReportedMessageIds: [String]?, completion: @escaping () -> Void) {
		switch result {
		case .Success(let fetchResponse):
			MMLogDebug("[Message fetching] succeded: received \(String(describing: fetchResponse.messages?.count))")

			if let nonReportedMessageIds = nonReportedMessageIds {
				self.dequeueDeliveryReports(messageIDs: nonReportedMessageIds, completion: completion)
				MMLogDebug("[Message fetching] delivery report sent for messages: \(nonReportedMessageIds)")
				UserEventsManager.postDLRSentEvent(nonReportedMessageIds)
			} else {
				completion()
			}
		case .Failure(_):
			MMLogError("[Message fetching] request failed")
			completion()
		case .Cancel:
			MMLogWarn("[Message fetching] cancelled")
			completion()
		}
	}
	
	private func dequeueDeliveryReports(messageIDs: [String], completion: @escaping () -> Void) {
		context.performAndWait {
			guard let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageTypeValue == \(MMMessageType.Default.rawValue) AND messageId IN %@", messageIDs), context: context)
				, !messages.isEmpty else
			{
				completion()
				return
			}

			messages.forEach {
				$0.reportSent = true
				$0.deliveryReportedDate = MobileMessaging.date.now
			}

			MMLogDebug("[Message fetching] marked as delivered: \(messages.map{ $0.messageId })")
			context.MM_saveToPersistentStoreAndWait()
			updateMessageStorage(with: messages, completion: completion)
		}
	}
	
	private func updateMessageStorage(with messages: [MessageManagedObject], completion: @escaping () -> Void) {
		guard !messages.isEmpty else
		{
			completion()
			return
		}
		let storages = mmContext.messageStorages.values
		storages.forEachAsync({ (storage, finishBlock) in
			storage.batchDeliveryStatusUpdate(messages: messages, completion: finishBlock)
		}, completion: completion)
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Message fetching] finished with errors: \(errors)")
		
		switch result {
		case .Success(let fetchResponse):
			if let messages = fetchResponse.messages, !messages.isEmpty, handlingIteration < Consts.MessageFetchingSettings.fetchingIterationLimit {
				MMLogDebug("[Message fetching] triggering handling for fetched messages \(messages.count)...")
				self.mmContext.messageHandler.handleMTMessages(messages, notificationTapped: false, handlingIteration: handlingIteration + 1, completion: { _ in
					self.finishBlock?(self.result)
				})
			} else {
				fallthrough
			}
		default:
			self.finishBlock?(result)
		}
	}
}
