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
	let mmContext: MobileMessaging
	
	init(context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		
		let regOp = SyncRegistrationOperation(context: context, mmContext: mmContext, finishBlock: nil)
		let systemDataOp = SystemDataSynchronizationOperation(сontext: context, mmContext: mmContext, finishBlock: nil)
		let userDataOp = UserDataSynchronizationOperation(syncOperationWithContext: context, mmContext: mmContext, finishBlock: nil)

		systemDataOp.addDependency(regOp)
		userDataOp.addDependency(regOp)
		
		super.init(operations: [regOp, systemDataOp, userDataOp])
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Installation syncing] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
