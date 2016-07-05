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

		let syncSeenOperation = SendSeenToServerOperation(context: context, remoteAPIQueue: remoteAPIQueue)
		
		super.init(operations: [syncSeenOperation])
		
		self.addCondition(RegistrationCondition())
		
		let syncOperation = SyncOperation(context: context, remoteAPIQueue: remoteAPIQueue)
		syncOperation.addDependency(syncSeenOperation)
		self.addOperation(syncOperation)
	}
	
	override func finished(errors: [NSError]) {
		finishBlock?(errors.first)
	}
}
