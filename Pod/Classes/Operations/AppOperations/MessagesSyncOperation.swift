//
//  MessagesSyncOperation.swift
//  Pods
//
//  Created by Andrey K. on 18/04/16.
//
//

import UIKit
import CoreData

class MessagesSyncOperation: GroupOperation {
	var context: NSManagedObjectContext
	var finishBlock: (NSError? -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	
	init(context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (NSError? -> Void)? = nil) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock

		let seenOperation = SendSeenOperation(context: context, remoteAPIQueue: remoteAPIQueue)
		
		super.init(operations: [seenOperation])
		
		self.addCondition(RegistrationCondition())
		
		if MMAPIKeys.kFetchAPIEnabled {
			let fetchOperation = MessagesFetchingOperation(context: context, remoteAPIQueue: remoteAPIQueue)
			fetchOperation.addDependency(seenOperation)
			self.addOperation(fetchOperation)
		} else {
			let deliverReportsOperation = DeliveryReportingOperation(context: context, remoteAPIQueue: remoteAPIQueue)
			deliverReportsOperation.addDependency(seenOperation)
			self.addOperation(deliverReportsOperation)
		}
	}
	
	override func finished(errors: [NSError]) {
		finishBlock?(errors.first)
	}
}
