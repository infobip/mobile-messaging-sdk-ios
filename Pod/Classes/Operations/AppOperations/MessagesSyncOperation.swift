//
//  MessagesSyncOperation.swift
//  Pods
//
//  Created by Andrey K. on 18/04/16.
//
//

import UIKit
import CoreData

final class MessagesSyncOperation: GroupOperation {
	var context: NSManagedObjectContext
	var finishBlock: (NSError? -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	
	init(context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (NSError? -> Void)? = nil) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock

		let seenOperation = SetSeenOperation(context: context, remoteAPIQueue: remoteAPIQueue)
		
		super.init(operations: [seenOperation])
		
		self.addCondition(RegistrationCondition())
		
		let syncOperation = SyncOperation(context: context, remoteAPIQueue: remoteAPIQueue)
		syncOperation.addDependency(seenOperation)
		self.addOperation(syncOperation)
	}
	
	override func finished(errors: [NSError]) {
		finishBlock?(errors.first)
	}
}
