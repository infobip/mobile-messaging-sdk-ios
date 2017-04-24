//
//  InstallationDataSynchronizationOperation.swift
//
//  Created by Andrey K. on 01/12/2016.
//
//

import Foundation
import CoreData

final class InstallationDataSynchronizationOperation: GroupOperation {
	let finishBlock: ((NSError?) -> Void)?
	let mmContext: MobileMessaging
	
	init(installation: MMInstallation, user: MMUser, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)? = nil) {
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		
		let regOp = SyncRegistrationOperation(installation: installation, user: user, mmContext: mmContext, finishBlock: nil)
		let systemDataOp = SystemDataSynchronizationOperation(installation: installation, user: user, mmContext: mmContext, finishBlock: nil)
		let userDataOp = UserDataSynchronizationOperation(syncOperationWithUser: user, mmContext: mmContext, finishBlock: nil)

		systemDataOp.addDependency(regOp)
		userDataOp.addDependency(regOp)
		
		super.init(operations: [regOp, systemDataOp, userDataOp])
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Installation syncing] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
