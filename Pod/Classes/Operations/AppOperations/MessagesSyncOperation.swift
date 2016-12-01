//
//  MessagesSyncOperation.swift
//
//  Created by Andrey K. on 18/04/16.
//
//

import UIKit
import CoreData

final class MessagesSyncOperation: GroupOperation {
	let context: NSManagedObjectContext
	let finishBlock: ((NSError?) -> Void)?
	
	init(context: NSManagedObjectContext, finishBlock: ((NSError?) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock

		let seenStatusSending = SeenStatusSendingOperation(context: context)
		
		super.init(operations: [seenStatusSending])
		
		let messageFetching = MessageFetchingOperation(context: context)
		messageFetching.addDependency(seenStatusSending)
		self.addOperation(messageFetching)
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Message syncing] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
