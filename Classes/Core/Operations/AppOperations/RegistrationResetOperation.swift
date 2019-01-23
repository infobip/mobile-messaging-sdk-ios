//
//  RegistrationResetOperation.swift
//
//  Created by Andrey K. on 12/02/17.
//
//

import UIKit
import CoreData

final class RegistrationResetOperation: Operation {
	let installation: InstallationDataService
	let user: UserDataService
	let finishBlock: ((NSError?) -> Void)?
	let apnsRegistrationManager: ApnsRegistrationManager
	
	init(user: UserDataService, installation: InstallationDataService, apnsRegistrationManager: ApnsRegistrationManager, finishBlock: ((NSError?) -> Void)?) {
		self.user = user
		self.installation = installation
		self.finishBlock = finishBlock
		self.apnsRegistrationManager = apnsRegistrationManager
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Registration reset] Started...")
		installation.pushRegistrationId = nil
		installation.deviceToken = nil
		installation.isPushRegistrationEnabled = true
		installation.isPrimaryDevice = false
		installation.persist()

		installation.depersonalizeFailCounter = 0
		installation.currentDepersonalizationStatus = .undefined
		user.persist()
		
		apnsRegistrationManager.setRegistrationIsHealthy()
		
		finish()
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Registration reset] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
