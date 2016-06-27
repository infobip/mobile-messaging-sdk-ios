//
//  RegistrationOperation.swift
//  Pods
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
		context.performBlockAndWait {
			guard let installation = InstallationManagedObject.MM_findFirstInContext(self.context) else {
				self.finish()
				return
			}
            if self.newDeviceToken != nil { // only store new token values
                installation.setDeviceTokenIfDifferent(self.newDeviceToken)
            }
			
			self.installationObject = installation
			
            if (self.installationHasChanges) {
                MMLogInfo("Saving installation locally...")
                self.context.MM_saveToPersistentStoreAndWait()
            } else {
                MMLogInfo("No need to save installation locally.")
            }
            
			self.sendRegistrationIfNeeded()
		}
	}
    
    private var installationHasChanges: Bool {
        return installationObject.changedValues().count > 0
    }
	
	private var registrationDataChanged: Bool {
		return deviceTokenChanged
	}
	
	private var deviceTokenChanged: Bool {
		return installationObject.dirtyAttributesSet.contains(SyncableAttributes.deviceToken)
	}
	
	private func sendRegistrationIfNeeded() {
		if (self.registrationDataChanged) {
			MMLogInfo("Sending the installation updates to server...")
			self.sendRegistration()
		} else {
			MMLogInfo("No need to send the installation on server.")
			finishWithError(NSError(type: MMInternalErrorType.OperationCanceled))
		}
	}
	
	private func sendRegistration() {
        guard let deviceToken = installationObject.deviceToken else {
            self.finishWithError(NSError(type: MMInternalErrorType.OperationCanceled))
            return
        }
        
		let request = MMPostRegistrationRequest(internalId: installationObject.internalId, deviceToken: deviceToken)
		self.remoteAPIQueue.performRequest(request) { result in
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
				MMLogInfo("Installation updated on server for internal ID \(regResponse.internalId). Updating local version...")
				installationObject.resetDirtyRegistration()
				installationObject.internalId = regResponse.internalId
				NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationRegistrationUpdated, userInfo: [MMNotificationKeyRegistrationInternalId: regResponse.internalId])
			case .Failure(let error):
				MMLogError("Registration request failed with error: \(error)")
			case .Cancel:
				return
			}
			
			self.context.MM_saveToPersistentStoreAndWait()
		}
	}
	
	override func finished(errors: [NSError]) {
		super.finished(errors)
		finishBlock?(errors.first)
	}
}