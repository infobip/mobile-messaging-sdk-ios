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
	
    init(newDeviceToken: Data? = nil, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: ((NSError?) -> Void)?) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		self.newDeviceToken = newDeviceToken?.mm_toHexString
        
		super.init()
	}
	
	override func execute() {
		context.performAndWait {
			guard let installation = InstallationManagedObject.MM_findFirstInContext(self.context) else {
				self.finish()
				return
			}
            if self.newDeviceToken != nil { // only store new token values
                installation.setDeviceTokenIfDifferent(token: self.newDeviceToken)
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
			finishWithError(NSError(type: MMInternalErrorType.OperationCanceled))
		}
	}
	
	private func sendRegistration() {
        guard let deviceToken = installationObject.deviceToken else {
            self.finishWithError(NSError(type: MMInternalErrorType.OperationCanceled))
            return
        }
        
		let request = MMPostRegistrationRequest(internalId: installationObject.internalUserId, deviceToken: deviceToken)
		self.remoteAPIQueue.performRequest(request) { result in
			self.handleRegistrationResult(result: result)
			self.finishWithError(result.error)
		}
	}
	
	private func handleRegistrationResult(result: MMRegistrationResult) {
		self.context.performAndWait {
			guard let installationObject = self.installationObject else {
				return
			}
			switch result {
			case .Success(let regResponse):
				MMLogDebug("Installation updated on server for internal ID \(regResponse.internalUserId). Updating local version...")
				installationObject.resetDirtyRegistration()
				installationObject.internalUserId = regResponse.internalUserId
				self.context.MM_saveToPersistentStoreAndWait()
				NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationRegistrationUpdated, userInfo: [MMNotificationKeyRegistrationInternalId: regResponse.internalUserId])
			case .Failure(let error):
				MMLogError("Registration request failed with error: \(error)")
				return
			case .Cancel:
				MMLogError("Registration request cancelled.")
				return
			}
		}
	}
	
	override func finished(_ errors: [NSError]) {
		finishBlock?(errors.first)
	}
}
