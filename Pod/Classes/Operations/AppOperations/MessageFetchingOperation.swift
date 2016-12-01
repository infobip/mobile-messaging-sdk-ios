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
	
	init(context: NSManagedObjectContext, finishBlock: ((MessagesSyncResult) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Message fetching] Starting operation...")
		self.syncMessages()
	}
	
	private func syncMessages() {
		guard let internalId = MobileMessaging.currentUser?.internalId else
		{
			self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		
		self.context.performAndWait {
			let date = NSDate(timeIntervalSinceNow: -60 * 60 * 24 * 7) // consider messages not older than 7 days
			let fetchLimit = 100 // consider 100 most recent messages
			let nonReportedMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "reportSent == false"), context: self.context)
			let archivedMessages = MessageManagedObject.MM_find(withPredicate: NSPredicate(format: "reportSent == true && creationDate > %@", date), fetchLimit: fetchLimit, sortedBy: "creationDate", ascending: false, inContext: self.context)
			
			let nonReportedMessageIds = nonReportedMessages?.map{ $0.messageId }
			let archveMessageIds = archivedMessages?.map{ $0.messageId }
			
			MMLogDebug("Found \(nonReportedMessageIds?.count) not reported messages. \(archivedMessages?.count) archive messages.")
			
			MobileMessaging.sharedInstance?.remoteApiManager.syncMessages(internalId: internalId, archiveMsgIds: archveMessageIds, dlrMsgIds: nonReportedMessageIds) { result in
				self.handleRequestResponse(result: result, nonReportedMessageIds: nonReportedMessageIds)
			}
		}
	}

	private func handleRequestResponse(result: MessagesSyncResult, nonReportedMessageIds: [String]?) {
		self.result = result
		
		self.context.performAndWait {
			switch result {
			case .Success(let fetchResponse):
				let fetchedMessages = fetchResponse.messages
				MMLogDebug("[Message fetching] succeded: received \(fetchedMessages?.count) new messages: \(fetchedMessages)")
				
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
		self.finishWithError(result.error as NSError?)
	}
	
	private func dequeueDeliveryReports(messageIDs: [String]) {
		guard let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIDs), context: context)
			, !messages.isEmpty
			else
		{
			return
		}
		
		messages.forEach { message in
			message.reportSent = true
		}
		
		MMLogDebug("[Message fetching] marked as delivered: \(messages.map{ $0.messageId })")
		context.MM_saveToPersistentStoreAndWait()
		
		self.updateMessageStorage(with: messages)
	}
	
	private func updateMessageStorage(with messages: [MessageManagedObject]) {
		messages.forEach({ MobileMessaging.sharedInstance?.messageStorageAdapter?.update(deliveryReportStatus: $0.reportSent , for: $0.messageId) })
	}
	
	private func handleMessageOperation(messages: [MTMessage]) -> MessageHandlingOperation {
		return MessageHandlingOperation(messagesToHandle: messages,
		                                messagesDeliveryMethod: .pull,
		                                context: self.context,
		                                messageHandler: MobileMessaging.messageHandling,
		                                applicationState: MobileMessaging.application.applicationState,
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
