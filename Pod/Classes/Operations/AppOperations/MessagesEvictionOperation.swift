//
//  MessagesEvictionOperation.swift
//  Pods
//
//  Created by Andrey K. on 16/05/16.
//
//

import UIKit
import CoreData


final class MessagesEvictionOperation: Operation {
	let kEntityExpirationPeriod: NSTimeInterval = 7 * 24 * 60 * 60; //one week
	var context: NSManagedObjectContext
	var finishBlock: (() -> Void)?
	
	init(context: NSManagedObjectContext, finishBlock: (() -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
	}
	
	override func execute() {
		self.context.performBlockAndWait {
			let dateToCompare = NSDate().dateByAddingTimeInterval(-self.kEntityExpirationPeriod)
			
			MessageManagedObject.MR_deleteAllMatchingPredicate(NSPredicate(format: "creationDate <= %@", dateToCompare), inContext: self.context)
			self.context.MR_saveToPersistentStoreAndWait()
		}
		finish()
	}
	
	override func finished(errors: [NSError]) {
		finishBlock?()
	}
}