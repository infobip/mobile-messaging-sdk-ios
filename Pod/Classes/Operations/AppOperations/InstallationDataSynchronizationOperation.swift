//
//  InstallationDataSynchronizationOperation.swift
//
//  Created by Andrey K. on 01/12/2016.
//
//

import Foundation
import CoreData

final class InstallationDataSynchronizationOperation: GroupOperation {
	let context: NSManagedObjectContext
	let finishBlock: ((NSError?) -> Void)?
	
	init(context: NSManagedObjectContext, finishBlock: ((NSError?) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		
		let regOp = SyncRegistrationOperation(context: context, finishBlock: nil)
		let systemDataOp = SystemDataSynchronizationOperation(сontext: context, finishBlock: nil)
		let userDataOp = UserDataSynchronizationOperation(syncOperationWithContext: context, finishBlock: nil)

		systemDataOp.addDependency(regOp)
		userDataOp.addDependency(regOp)
		
		super.init(operations: [regOp, systemDataOp, userDataOp])
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Installation syncing] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
