//
//  MessagesEvictionOperation.swift
//
//  Created by Andrey K. on 16/05/16.
//
//

import UIKit
import CoreData


final class MessagesEvictionOperation: MMOperation {
	
	var messageMaximumAge: TimeInterval
	var context: NSManagedObjectContext
	var finishBlock: (() -> Void)?
	
    init(userInitiated: Bool, context: NSManagedObjectContext, messageMaximumAge: TimeInterval? = nil, finishBlock: (() -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		self.messageMaximumAge = messageMaximumAge ?? Consts.SDKSettings.messagesRetentionPeriod
        super.init(isUserInitiated: userInitiated)
	}
	
	override func execute() {
		logDebug("started...")
		context.performAndWait {
			context.reset()
			let dateToCompare = MobileMessaging.date.now.addingTimeInterval(-self.messageMaximumAge)
			
			MessageManagedObject.MM_deleteAllMatchingPredicate(NSPredicate(format: "creationDate <= %@", dateToCompare as CVarArg), inContext: self.context)
			UserSessionReportObject.MM_deleteAllMatchingPredicate(NSPredicate(format: "startDate <= %@", dateToCompare as CVarArg), inContext: self.context)
			CustomEventObject.MM_deleteAllMatchingPredicate(NSPredicate(format: "eventDate <= %@", dateToCompare as CVarArg), inContext: self.context)
			self.context.MM_saveToPersistentStoreAndWait()
		}
		finish()
	}
	
	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		finishBlock?()
	}
}
