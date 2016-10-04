//
//  SeenStatusPersistingOperation.swift
//
//  Created by Andrey K. on 20/04/16.
//
//

import UIKit
import CoreData

final class SeenStatusPersistingOperation: Operation {
	var context: NSManagedObjectContext
	var finishBlock: (() -> Void)?
	var messageIds: [String]
	
	init(messageIds: [String], context: NSManagedObjectContext, finishBlock: (() -> Void)? = nil) {
		self.messageIds = messageIds
		self.context = context
		self.finishBlock = finishBlock
	}
	
	override func execute() {
		self.markMessagesAsSeen()
	}
	
	private func markMessagesAsSeen() {
		self.context.performAndWait {
			guard self.messageIds.count > 0 else {
				return
			}

			if let dbMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", self.messageIds), context: self.context), !dbMessages.isEmpty {
				dbMessages.forEach { message in
					switch message.seenStatus {
					case .NotSeen:
						message.seenStatus = .SeenNotSent
						message.seenDate = NSDate()
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
		messages.forEach { MobileMessaging.sharedInstance?.messageStorageAdapter?.update(messageSeenStatus: $0.seenStatus , for: $0.messageId) }
	}
	
	override func finished(_ errors: [NSError]) {
		finishBlock?()
	}
}
