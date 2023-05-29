//
//  RegistrationResetOperation.swift
//
//  Created by Andrey K. on 12/02/17.
//
//

import UIKit
import CoreData

final class RegistrationResetOperation: MMOperation {
	
	let mmContext: MobileMessaging
	let finishBlock: ((NSError?) -> Void)?
	let apnsRegistrationManager: ApnsRegistrationManager
	
    init(userInitiated: Bool, mmContext: MobileMessaging, apnsRegistrationManager: ApnsRegistrationManager, finishBlock: ((NSError?) -> Void)?) {
		self.finishBlock = finishBlock
		self.apnsRegistrationManager = apnsRegistrationManager
		self.mmContext = mmContext
		super.init(isUserInitiated: userInitiated)
	}
	
	override func execute() {
		logDebug("Started...")
		MMInstallation.empty.archiveAll()
		apnsRegistrationManager.setRegistrationIsHealthy()
		
		finish()
	}
	
	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
