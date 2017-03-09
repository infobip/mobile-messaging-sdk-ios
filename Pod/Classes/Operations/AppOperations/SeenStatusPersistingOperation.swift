//
//  SeenStatusPersistingOperation.swift
//
//  Created by Andrey K. on 20/04/16.
//
//

import UIKit
import CoreData

final class SeenStatusPersistingOperation: Operation {
	let context: NSManagedObjectContext
	let finishBlock: (() -> Void)?
	let messageIds: [String]
	let mmContext: MobileMessaging
	
	init(messageIds: [String], context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: (() -> Void)? = nil) {
		self.messageIds = messageIds
		self.context = context
		self.finishBlock = finishBlock
		self.mmContext = mmContext
	}
	
	override func execute() {
		MMLogDebug("[Seen status persisting] started...")
		context.reset()
		markMessagesAsSeen()
	}
	
	private func markMessagesAsSeen() {
		guard !self.messageIds.isEmpty else {
			finish()
			return
		}
		self.context.performAndWait {
			if let dbMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "seenStatusValue == \(MMSeenStatus.NotSeen.rawValue) AND messageTypeValue == \(MMMessageType.Default.rawValue) AND messageId IN %@", self.messageIds), context: self.context), !dbMessages.isEmpty {
				dbMessages.forEach { message in
					switch message.seenStatus {
					case .NotSeen:
						message.seenStatus = .SeenNotSent
						message.seenDate = MobileMessaging.date.now // we store only the very first seen date, any repeated seen update is ignored
					case .SeenSent:
						message.seenStatus = .SeenNotSent
					case .SeenNotSent: break
					}
				}
				self.context.MM_saveToPersistentStoreAndWait()
				self.updateMessageStorage(with: dbMessages)
			}
		}
		finish()
	}
	
	private func updateMessageStorage(with messages: [MessageManagedObject]) {
		messages.forEach { mmContext.messageStorageAdapter?.update(messageSeenStatus: $0.seenStatus , for: $0.messageId) }
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Seen status persisting] finished with errors: \(errors)")
		finishBlock?()
	}
}
