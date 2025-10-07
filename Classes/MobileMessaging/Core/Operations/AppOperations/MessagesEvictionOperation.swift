// 
//  MessagesEvictionOperation.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
        logDebug("finished with errors: \(errors)")
		finishBlock?()
	}
}
