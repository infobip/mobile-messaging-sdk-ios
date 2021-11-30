//
//  SeenStatusPersistingOperation.swift
//
//  Created by Andrey K. on 20/04/16.
//
//

import UIKit
import CoreData

final class SeenStatusPersistingOperation: MMOperation {
	
	let context: NSManagedObjectContext
	let finishBlock: (() -> Void)?
	let messageIds: [String]
	let mmContext: MobileMessaging
	
    init(userInitiated: Bool, messageIds: [String], context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: (() -> Void)? = nil) {
		self.messageIds = messageIds
		self.context = context
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		super.init(isUserInitiated: userInitiated)
	}
	
	override func execute() {
		logDebug("started...")
		markMessagesAsSeen()
	}
	
	private func markMessagesAsSeen() {
		guard !self.messageIds.isEmpty else {
			logDebug("no messages to mark seen. Finishing")
			finish()
			return
		}
		context.performAndWait {
			context.reset()
			if let dbMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "seenStatusValue == \(MMSeenStatus.NotSeen.rawValue) AND messageTypeValue == \(MMMessageType.Default.rawValue) AND messageId  IN %@", self.messageIds), context: self.context), !dbMessages.isEmpty {

				dbMessages.forEach { message in
					logDebug("message \(message.messageId) marked as seen")
					message.seenStatus = .SeenNotSent
					message.seenDate = MobileMessaging.date.now // we store only the very first seen date, any repeated seen update is ignored
				}
				self.context.MM_saveToPersistentStoreAndWait()
			} else {
				logDebug("no messages in internal storage to set seen")
			}

			self.updateMessageStorage(with: messageIds) {
				self.finish()
			}
		}
	}
	
	private func updateMessageStorage(with messageIds: [String], completion: @escaping () -> Void) {
		guard !messageIds.isEmpty else {
			logDebug("no message ids to set seen in message storage")
			completion()
			return
		}
		logDebug("updating message storage")
		mmContext.messageStorages.values.forEachAsync({ (storage, finishBlock) in
			storage.batchSeenStatusUpdate(messageIds: messageIds, seenStatus: .SeenNotSent, completion: finishBlock)
		}, completion: completion)
	}
	
	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		finishBlock?()
	}
}
