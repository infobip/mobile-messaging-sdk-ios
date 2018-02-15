//
//  RegistrationResetOperation.swift
//
//  Created by Andrey K. on 12/02/17.
//
//

import UIKit
import CoreData

final class RegistrationResetOperation: Operation {
	let installation: MMInstallation
	let user: MMUser
	let finishBlock: ((NSError?) -> Void)?
	let apnsRegistrationManager: ApnsRegistrationManager
	
	init(installation: MMInstallation, user: MMUser, apnsRegistrationManager: ApnsRegistrationManager, finishBlock: ((NSError?) -> Void)?) {
		self.installation = installation
		self.user = user
		self.finishBlock = finishBlock
		self.apnsRegistrationManager = apnsRegistrationManager
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Registration reset] Started...")
		user.pushRegistrationId = nil
		installation.deviceToken = nil
		installation.isPushRegistrationEnabled = true
		
		user.persist()
		installation.persist()
		
		apnsRegistrationManager.setRegistrationIsHealthy()
		
		finish()
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Registration reset] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
