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
	let mmContext: MobileMessaging
	
	init(context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		
		let seenStatusSending = SeenStatusSendingOperation(context: context, mmContext: mmContext)
		
		super.init(operations: [seenStatusSending])
		
		let messageFetching = MessageFetchingOperation(context: context, mmContext: mmContext)
		messageFetching.addDependency(seenStatusSending)
		self.addOperation(messageFetching)
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Message syncing] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
