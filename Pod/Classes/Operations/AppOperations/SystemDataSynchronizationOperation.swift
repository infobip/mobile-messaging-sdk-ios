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
	let finishBlock: ((NSError?) -> Void)?
	let remoteAPIQueue: MMRemoteAPIQueue
	private var installationObject: InstallationManagedObject!
	
	lazy var currentSystemData: MMSystemData = {
		return MobileMessaging.userAgent.systemData
	}()
	
	lazy var currentSystemDataHash: Int = {
		return self.currentSystemData.hashValue
	}()
	
	init(сontext context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: ((NSError?) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		self.remoteAPIQueue = remoteAPIQueue
		super.init()
		
		self.addCondition(RegistrationCondition(internalId: MobileMessaging.currentUser?.internalId))
	}
	
	override func execute() {
		MMLogDebug("System Data: starting synchronization...")
		context.performAndWait {
			guard let installation = InstallationManagedObject.MM_findFirstInContext(self.context) else
			{
				MMLogDebug("System Data: installation object not found, finishing the operation.")
				self.finish()
				return
			}
			self.installationObject = installation
			
			if installation.systemDataHash != self.currentSystemDataHash {
				self.sendRequest()
			} else {
				self.finish()
			}
		}
	}
	
	private func sendRequest() {
		guard let user = MobileMessaging.currentUser, let internalId = user.internalId else
		{
			self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		
		let request = MMPostSystemDataRequest(internalUserId: internalId, systemData: currentSystemData)
		MMLogDebug("System Data: performing request...")
		remoteAPIQueue.perform(request: request) { result in
			self.handleResult(result)
			self.finishWithError(result.error)
		}
	}
	
	private func handleResult(_ result: MMSystemDataSyncResult) {
		context.performAndWait {
			switch result {
			case .Success:
				guard let installationObject = self.installationObject else {
					return
				}
				installationObject.systemDataHash = NSNumber(value: self.currentSystemDataHash)
				self.context.MM_saveToPersistentStoreAndWait()
				MMLogDebug("System Data: successfully synced")
			case .Failure(let error):
				MMLogError("System Data: sync request failed with error: \(error)")
				return
			case .Cancel:
				MMLogError("System Data: sync request cancelled.")
				return
			}
		}
	}
	
	override func finished(_ errors: [NSError]) {
		self.finishBlock?(errors.first)
	}
}
