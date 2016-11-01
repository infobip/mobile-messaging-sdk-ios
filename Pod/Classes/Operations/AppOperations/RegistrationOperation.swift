//
//  RegistrationOperation.swift
//
//  Created by Andrey K. on 18/04/16.
//
//

import UIKit
import CoreData

final class RegistrationOperation: Operation {

	var context: NSManagedObjectContext
	var installationObject: InstallationManagedObject!
	var finishBlock: ((NSError?) -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	var newDeviceToken: String?
	
    init(newDeviceToken: NSData? = nil, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: ((NSError?) -> Void)?) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		self.newDeviceToken = newDeviceToken?.mm_toHexString
        
		super.init()
	}
	
	override func execute() {
		context.performBlock {
			guard let installation = InstallationManagedObject.MM_findFirstInContext(context: self.context) else {
				self.finish()
				return
			}
			
            if self.newDeviceToken != nil { // only store new token values
                installation.setDeviceTokenIfDifferent(self.newDeviceToken)
            }
			
			self.installationObject = installation
			
            if (self.installationHasChanges) {
                MMLogDebug("Saving installation locally...")
                self.context.MM_saveToPersistentStoreAndWait()
            } else {
                MMLogDebug("No need to save installation locally.")
            }
            
			self.sendRegistrationIfNeeded()
		}
	}
    
    private var installationHasChanges: Bool {
        return installationObject.changedValues().count > 0
    }
	
	private var registrationDataChanged: Bool {
		return installationObject.dirtyAttributesSet.contains(SyncableAttributesSet.deviceToken)
	}
	
	private func sendRegistrationIfNeeded() {
		if self.registrationDataChanged {
			MMLogDebug("Sending the registration updates to server...")
			self.sendRegistration()
		} else {
			MMLogDebug("No need to send the installation on server.")
			finish()
		}
	}
	
	private func sendRegistration() {
        guard let deviceToken = installationObject.deviceToken else {
            self.finish()
            return
        }
        
		let request = MMPostRegistrationRequest(internalId: installationObject.internalUserId, deviceToken: deviceToken)
		self.remoteAPIQueue.perform(request: request) { result in
			self.handleRegistrationResult(result)
			self.finishWithError(result.error)
		}
	}
	
	private func handleRegistrationResult(result: MMRegistrationResult) {
		self.context.performBlockAndWait {
			guard let installationObject = self.installationObject else {
				return
			}
			switch result {
			case .Success(let regResponse):
				MMLogDebug("Installation updated on server for internal ID \(regResponse.internalUserId). Updating local version...")
				installationObject.resetDirtyRegistration()
				installationObject.internalUserId = regResponse.internalUserId
				self.context.MM_saveToPersistentStoreAndWait()
				NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationRegistrationUpdated, userInfo: [MMNotificationKeyRegistrationInternalId: regResponse.internalUserId])
			case .Failure(let error):
				MMLogError("Registration request failed with error: \(error)")
			case .Cancel:
				MMLogError("Registration request cancelled.")
			}
		}
	}
	
	override func finished(errors: [NSError]) {
		if errors.isEmpty {
			let systemDataSync = SystemDataSynchronizationOperation(сontext: self.context, remoteAPIQueue: remoteAPIQueue, finishBlock: { error in
				self.finishBlock?(error)
			})
			self.produceOperation(systemDataSync)
		} else {
			finishBlock?(errors.first)
		}
	}
}
