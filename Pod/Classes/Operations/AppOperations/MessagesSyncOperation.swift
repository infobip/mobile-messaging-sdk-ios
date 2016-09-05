//
//  MessagesSyncOperation.swift
//
//  Created by Andrey K. on 18/04/16.
//
//

import UIKit
import CoreData

final class MessagesSyncOperation: GroupOperation {
	var context: NSManagedObjectContext
	var finishBlock: ((NSError?) -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	
	init(context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: ((NSError?) -> Void)? = nil) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock

		let seenStatusSending = SeenStatusSendingOperation(context: context, remoteAPIQueue: remoteAPIQueue)
		
		super.init(operations: [seenStatusSending])
		
		self.addCondition(RegistrationCondition(internalId: MobileMessaging.currentUser?.internalId))
		
		let messageFetching = MessageFetchingOperation(context: context, remoteAPIQueue: remoteAPIQueue)
		messageFetching.addDependency(seenStatusSending)
		self.addOperation(messageFetching)
	}
	
	override func finished(_ errors: [NSError]) {
		finishBlock?(errors.first)
	}
}
