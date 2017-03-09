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
	let context: NSManagedObjectContext
	let mmContext: MobileMessaging
	let finishBlock: ((NSError?) -> Void)?
	private var installationObject: InstallationManagedObject!
	
	lazy var currentSystemData: MMSystemData = {
		return MobileMessaging.userAgent.systemData
	}()
	
	lazy var currentSystemDataHash: Int64 = {
		return Int64(self.currentSystemData.hashValue)
	}()
	
	init(сontext context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[System data sync] starting synchronization...")
		context.perform {
			guard let installation = InstallationManagedObject.MM_findFirstInContext(self.context) else
			{
				MMLogDebug("[System data sync] installation object not found, finishing the operation...")
				self.finish()
				return
			}
			self.installationObject = installation
			
			if installation.systemDataHash != self.currentSystemDataHash {
				self.sendRequest()
			} else {
				MMLogDebug("[System data sync] no changes to send to the server")
				self.finish()
			}
		}
	}
	
	private func sendRequest() {
		guard let internalId = installationObject.internalUserId else
		{
			self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
        
		MMLogDebug("[System data sync] performing request...")
		
		mmContext.remoteApiManager.syncSystemData(internalUserId: internalId, systemData: currentSystemData) { result in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}
	
	private func handleResult(_ result: SystemDataSyncResult) {
		context.performAndWait {
			switch result {
			case .Success:
				self.installationObject.systemDataHash = self.currentSystemDataHash
				self.context.MM_saveToPersistentStoreAndWait()
				MMLogDebug("[System data sync] successfully synced")
			case .Failure(let error):
				MMLogError("[System data sync] sync request failed with error: \(error)")
			case .Cancel:
				MMLogError("[System data sync] sync request cancelled.")
			}
		}
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[System data sync] finished with errors: \(errors)")
		self.finishBlock?(errors.first)
	}
}
