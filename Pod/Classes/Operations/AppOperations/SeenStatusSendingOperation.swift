//
//  SeenStatusSendingOperation.swift
//
//  Created by Andrey K. on 05/07/16.
//
//

import UIKit
import CoreData

class SeenStatusSendingOperation: Operation {
	var context: NSManagedObjectContext
	var finishBlock: ((MMSeenMessagesResult) -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	var result = MMSeenMessagesResult.Cancel
	
	init(context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: ((MMSeenMessagesResult) -> Void)? = nil) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
	}
	
	override func execute() {
		self.context.perform {
			guard let seenNotSentMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "seenStatusValue == \(MMSeenStatus.SeenNotSent.rawValue)"), context: self.context), !seenNotSentMessages.isEmpty else
			{
				MMLogDebug("[Seen status reporting] There is no non-seen meessages to send to the server. Finishing...")
				self.finish()
				return
			}
			
			let seenStatusesToSend = seenNotSentMessages.flatMap { msg -> SeenData? in
				guard let seenDate = msg.seenDate else {
					return nil
				}
				return SeenData(messageId: msg.messageId, seenDate: seenDate)
			}
			
			let request = MMPostSeenMessagesRequest(seenList: seenStatusesToSend)
			self.remoteAPIQueue.perform(request: request) { result in
				self.handleSeenResult(result, seenMessageIds: seenStatusesToSend.map { $0.messageId })
				self.finishWithError(result.error)
			}
		}
	}
	
	private func handleSeenResult(_ result: MMSeenMessagesResult, seenMessageIds:[String]) {
		self.result = result
		switch result {
		case .Success(_):
			MMLogDebug("[Seen status reporting] Request succeeded")

			context.performAndWait {
				if let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format:"messageId IN %@", seenMessageIds), context: self.context), !messages.isEmpty
				{
					messages.forEach { message in
						message.seenStatus = .SeenSent
					}
					self.context.MM_saveToPersistentStoreAndWait()
					self.updateMessageStorage(with: messages)
				}
			}
		case .Failure(let error):
			MMLogError("[Seen status reporting] Request failed with error: \(error)")
		case .Cancel:
			break
		}
	}
	
	private func updateMessageStorage(with messages: [MessageManagedObject]) {
		messages.forEach { MobileMessaging.messageStorage?.update(messageSeenStatus: $0.seenStatus , for: $0.messageId) }
	}
	
	override func finished(_ errors: [NSError]) {
		if let error = errors.first {
			result = MMSeenMessagesResult.Failure(error)
		}
		finishBlock?(result)
	}
}
