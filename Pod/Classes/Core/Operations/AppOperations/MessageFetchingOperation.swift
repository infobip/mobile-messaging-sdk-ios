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
	
	init(context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: ((MessagesSyncResult) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Message fetching] Starting operation...")
		context.reset()
		syncMessages()
	}
	
	private func syncMessages() {
		self.context.performAndWait {
			let date = MobileMessaging.date.timeInterval(sinceNow: -60 * 60 * 24 * 7) // consider messages not older than 7 days
			let fetchLimit = 100 // consider 100 most recent messages
			let nonReportedMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "reportSent == false"), context: self.context)
			let archivedMessages = MessageManagedObject.MM_find(withPredicate: NSPredicate(format: "reportSent == true && creationDate > %@", date as CVarArg), fetchLimit: fetchLimit, sortedBy: "creationDate", ascending: false, inContext: self.context)
			
			let nonReportedMessageIds = nonReportedMessages?.map{ $0.messageId }
			let archveMessageIds = archivedMessages?.map{ $0.messageId }
			
			MMLogDebug("[Message fetching] Found \(String(describing: nonReportedMessageIds?.count)) not reported messages. \(String(describing: archivedMessages?.count)) archive messages.")
			
           self.mmContext.remoteApiManager.syncMessages(archiveMsgIds: archveMessageIds, dlrMsgIds: nonReportedMessageIds) { result in
                self.result = result
                self.handleRequestResponse(result: result, nonReportedMessageIds: nonReportedMessageIds)
                self.finishWithError(result.error as NSError?)
            }
		}
	}

	private func handleRequestResponse(result: MessagesSyncResult, nonReportedMessageIds: [String]?) {
		self.context.performAndWait {
			switch result {
			case .Success(let fetchResponse):
				let fetchedMessages = fetchResponse.messages
				MMLogDebug("[Message fetching] succeded: received \(String(describing: fetchedMessages?.count))")
				
				if let nonReportedMessageIds = nonReportedMessageIds {
					self.dequeueDeliveryReports(messageIDs: nonReportedMessageIds)
					MMLogDebug("[Message fetching] delivery report sent for messages: \(nonReportedMessageIds)")
					if !nonReportedMessageIds.isEmpty {
						NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationDeliveryReportSent, userInfo: [MMNotificationKeyDLRMessageIDs: nonReportedMessageIds])
					}
				}
			case .Failure(_):
				MMLogError("[Message fetching] request failed")
			case .Cancel:
				MMLogDebug("[Message fetching] cancelled")
			}
		}
	}
	
	private func dequeueDeliveryReports(messageIDs: [String]) {
		guard let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIDs), context: context)
			, !messages.isEmpty else
        {
			return
		}
		
		messages.forEach { message in
			message.reportSent = true
			message.deliveryReportedDate = MobileMessaging.date.now
		}
		
		MMLogDebug("[Message fetching] marked as delivered: \(messages.map{ $0.messageId })")
		context.MM_saveToPersistentStoreAndWait()
		
		self.updateMessageStorage(with: messages)
	}
	
	private func updateMessageStorage(with messages: [MessageManagedObject]) {
		messages.forEach({ mmContext.messageStorageAdapter?.update(deliveryReportStatus: $0.reportSent , for: $0.messageId) })
	}
	
	private func handleMessageOperation(messages: [MTMessage]) -> MessageHandlingOperation {
		return MessageHandlingOperation(messagesToHandle: messages,
		                                context: context,
		                                messageHandler: MobileMessaging.messageHandling,
		                                applicationState: mmContext.application.applicationState,
		                                mmContext: mmContext,
		                                finishBlock: { error in
											
											var finalResult = self.result
											if let error = error {
												finalResult = MessagesSyncResult.Failure(error)
											}
											self.finishBlock?(finalResult)
		})
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Message fetching] finished with errors: \(errors)")
		let finishResult = errors.isEmpty ? result : MessagesSyncResult.Failure(errors.first)
		switch finishResult {
		case .Success(let fetchResponse):
			if let messages = fetchResponse.messages , !messages.isEmpty {
				self.produceOperation(handleMessageOperation(messages: messages))
			} else {
				self.finishBlock?(result)
			}
		default:
			self.finishBlock?(result)
		}
	}
}
