// 
//  RegistrationResetOperation.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
        logDebug("finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
