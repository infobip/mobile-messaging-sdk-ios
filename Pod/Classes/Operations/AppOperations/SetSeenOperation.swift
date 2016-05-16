//
//  SendSeenOperation.swift
//  Pods
//
//  Created by Andrey K. on 20/04/16.
//
//

import UIKit
import CoreData

struct SeenData {
	let messageId: String
	let supplementaryId: String
	let seenTimestamp: String
	var dict: [String: String] {
		return [MMAPIKeys.kMessageId: messageId,
		        MMAPIKeys.kSupplementaryId: supplementaryId,
		        MMAPIKeys.kSeenTimestamp: seenTimestamp]
	}
	static func requestBody(seenList: [SeenData]) -> [String: AnyObject] {
		return [MMAPIKeys.kSeenMessages: seenList.map{ $0.dict } ]
	}
}


final class SetSeenOperation: Operation {
	var context: NSManagedObjectContext
	var finishBlock: (MMSeenMessagesResult -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	var messageIds: [String]?
	var result = MMSeenMessagesResult.Failure(NSError(type: .UnknownError))
	
	init(messageIds: [String]? = nil, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (MMSeenMessagesResult -> Void)? = nil) {
		self.messageIds = messageIds
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
	}
	
	override func execute() {
		if MMAPIKeys.kSeenAPIEnabled {
			self.context.performBlockAndWait {
				self.markMessagesAsSeen()
				self.sendSeen()
			}
		} else {
			finish()
		}
	}
	
	private func markMessagesAsSeen() {
		guard let messageIds = self.messageIds where messageIds.count > 0 else {
			return
		}
		if let dbMessages = MessageManagedObject.MR_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIds), inContext: self.context) as? [MessageManagedObject] {
			for message in dbMessages {
				switch message.seenStatus {
				case .NotSeen :
					message.seenStatus = .SeenNotSent
					message.seenDate = NSDate()
				case .SeenSent:
					message.seenStatus = .SeenNotSent
				case .SeenNotSent: break
				}
			}
			self.context.MR_saveOnlySelfAndWait()
		}
	}
	
	private func sendSeen() {
		guard let seenNotSentMessages = MessageManagedObject.MR_findAllWithPredicate(NSPredicate(format: "seenStatusValue == \(MMSeenStatus.SeenNotSent.rawValue)"), inContext: self.context) as? [MessageManagedObject]
			where seenNotSentMessages.count > 0
			else
		{
			MMLogDebug("There is no unseen meessages to send on server. Finishing...")
			self.finish()
			return
		}
		
		let seenStatusesToSend = seenNotSentMessages.flatMap { msg -> SeenData? in
			guard let date = msg.seenDate else {
				return nil
			}
			return SeenData(messageId: msg.messageId, supplementaryId: msg.supplementaryId, seenTimestamp: String(date.timeIntervalSince1970))
		}
		
		let request = MMPostSeenMessagesRequest(seenList: seenStatusesToSend)
		self.remoteAPIQueue.performRequest(request) { result in
			self.handleSeenResult(result, seenMessageIds: seenStatusesToSend.map { $0.messageId })
		}
	}

	
	private func handleSeenResult(result: MMSeenMessagesResult, seenMessageIds:[String]) {
		self.result = result
		switch result {
		case .Success(_):
			MMLogInfo("Seen messages request succeded")
			
			context.performBlockAndWait {
				if let messages = MessageManagedObject.MR_findAllWithPredicate(NSPredicate(format:"messageId IN %@", seenMessageIds), inContext: self.context) as? [MessageManagedObject] where messages.count > 0 {
					for message in messages {
						message.seenStatus = .SeenSent
					}
					self.context.MR_saveOnlySelfAndWait()
				}
			}
			
		case .Failure(let error):
			MMLogError("Seen messages request failed with error: \(error)")
		case .Cancel: break
		}
		finishWithError(result.error)
	}
	
	override func finished(errors: [NSError]) {
		finishBlock?(result)
	}
}
