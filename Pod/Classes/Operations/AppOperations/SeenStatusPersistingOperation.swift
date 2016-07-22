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
		self.context.performBlockAndWait {
			guard self.messageIds.count > 0 else {
				return
			}
			if let dbMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", self.messageIds), inContext: self.context) as? [MessageManagedObject] where dbMessages.count > 0 {
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
				self.context.MM_saveToPersistentStoreAndWait()
			}
		}
		finish()
	}
	
	override func finished(errors: [NSError]) {
		finishBlock?()
	}
}
