//
//  MessagesEvictionOperation.swift
//
//  Created by Andrey K. on 16/05/16.
//
//

import UIKit
import CoreData


final class MessagesEvictionOperation: Operation {
	var messageMaximumAge: TimeInterval
	var context: NSManagedObjectContext
	var finishBlock: (() -> Void)?
	
	init(context: NSManagedObjectContext, messageMaximumAge: TimeInterval? = nil, finishBlock: (() -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		self.messageMaximumAge = messageMaximumAge ?? Consts.SDKSettings.messagesRetentionPeriod
	}
	
	override func execute() {
		MMLogDebug("[Message eviction] started...")
		context.performAndWait {
			context.reset()
			let dateToCompare = MobileMessaging.date.now.addingTimeInterval(-self.messageMaximumAge)
			
			MessageManagedObject.MM_deleteAllMatchingPredicate(NSPredicate(format: "creationDate <= %@", dateToCompare as CVarArg), inContext: self.context)
			self.context.MM_saveToPersistentStoreAndWait()
		}
		finish()
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Message eviction] finished with errors: \(errors)")
		finishBlock?()
	}
}
