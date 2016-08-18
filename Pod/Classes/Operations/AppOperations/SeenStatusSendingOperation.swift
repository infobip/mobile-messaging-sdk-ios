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
	var finishBlock: (MMSeenMessagesResult -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	var result = MMSeenMessagesResult.Cancel
	
	init(context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (MMSeenMessagesResult -> Void)? = nil) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
	}
	
	override func execute() {
		self.sendSeen()
	}
	
	private func sendSeen() {
		self.context.performBlockAndWait {
			guard let seenNotSentMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "seenStatusValue == \(MMSeenStatus.SeenNotSent.rawValue)"), inContext: self.context) as? [MessageManagedObject]
				where seenNotSentMessages.count > 0
				else
			{
				MMLogDebug("There is no unseen meessages to send on server. Finishing...")
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
			self.remoteAPIQueue.performRequest(request) { result in
				self.handleSeenResult(result, seenMessageIds: seenStatusesToSend.map { $0.messageId })
				self.finishWithError(result.error)
			}
		}
	}
	
	private func handleSeenResult(result: MMSeenMessagesResult, seenMessageIds:[String]) {
		self.result = result
		switch result {
		case .Success(_):
			MMLogDebug("Seen messages request succeded")
			
			context.performBlockAndWait {
				if let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format:"messageId IN %@", seenMessageIds), inContext: self.context) as? [MessageManagedObject] where messages.count > 0 {
					for message in messages {
						message.seenStatus = .SeenSent
					}
					self.context.MM_saveToPersistentStoreAndWait()
				}
			}
			
		case .Failure(let error):
			MMLogError("Seen messages request failed with error: \(error)")
		case .Cancel: break
		}
	}
	
	override func finished(errors: [NSError]) {
		if let error = errors.first {
			result = MMSeenMessagesResult.Failure(error)
		}
		finishBlock?(result)
	}
}
