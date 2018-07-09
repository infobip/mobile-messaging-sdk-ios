//
//  SystemDataSynchronizationOperation.swift
//
//  Created by Andrey K. on 25/08/16.
//
//

import UIKit
import CoreData
import Security

class SystemDataSynchronizationOperation: Operation {
	let installation: MMInstallation
	let user: MMUser
	let mmContext: MobileMessaging
	let finishBlock: ((NSError?) -> Void)?
	
	lazy var currentSystemData: SystemData = {
		return MobileMessaging.userAgent.systemData
	}()
	
	lazy var currentSystemDataHash: Int64 = {
		return Int64(self.currentSystemData.hashValue)
	}()
	
	init(installation: MMInstallation, user: MMUser, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)? = nil) {
		self.installation = installation
		self.user = user
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[System data sync] starting synchronization...")
		
		if installation.systemDataHash != currentSystemDataHash {
			sendRequest()
		} else {
			MMLogDebug("[System data sync] no changes to send to the server")
			finish()
		}
	}
	
	private func sendRequest() {
		guard let pushRegistrationId = user.pushRegistrationId else {
			MMLogDebug("[System data sync] No registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogDebug("[System data sync] Registration may be not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		
		MMLogDebug("[System data sync] performing request...")
		mmContext.remoteApiProvider.syncSystemData(applicationCode: self.mmContext.applicationCode, pushRegistrationId: pushRegistrationId, systemData: currentSystemData) { result in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}
	
	private func handleResult(_ result: SystemDataSyncResult) {
		switch result {
		case .Success:
			installation.systemDataHash = currentSystemDataHash
			guard !isCancelled else {
				return
			}
			installation.persist()
			MMLogDebug("[System data sync] successfully synced")
		case .Failure(let error):
			MMLogError("[System data sync] sync request failed with error: \(error.orNil)")
		case .Cancel:
			MMLogError("[System data sync] sync request cancelled.")
		}
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[System data sync] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
