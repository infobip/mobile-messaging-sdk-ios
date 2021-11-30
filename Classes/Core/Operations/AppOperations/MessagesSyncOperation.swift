//
//  MessagesSyncOperation.swift
//
//  Created by Andrey K. on 18/04/16.
//
//

import UIKit
import CoreData

final class MessagesSyncOperation: GroupOperation {
	static var loggerName: String = String(describing: self)
	let context: NSManagedObjectContext
	let finishBlock: ((NSError?) -> Void)?
	let mmContext: MobileMessaging
	
    init(userInitiated: Bool, context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		self.mmContext = mmContext

        let seenStatusSending = SeenStatusSendingOperation(userInitiated: false, context: context, mmContext: mmContext)
		
		super.init(operations: [seenStatusSending])
		
        let messageFetching = MessageFetchingOperation(userInitiated: userInitiated, context: context, mmContext: mmContext, finishBlock: { _ in })
		messageFetching.addDependency(seenStatusSending)
		self.addOperation(messageFetching)
	}
	
	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
