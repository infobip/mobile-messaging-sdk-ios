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
		context.perform {
			guard let installation = InstallationManagedObject.MM_findFirstInContext(self.context) else {
				self.finish()
				return
			}
			
            if self.newDeviceToken != nil { // only store new token values
                installation.setDeviceTokenIfDifferent(token: self.newDeviceToken)
            }
			
			self.installationObject = installation
			
            if (self.installationHasChanges) {
                MMLogDebug("[Registration] Saving installation locally...")
                self.context.MM_saveToPersistentStoreAndWait()
            } else {
                MMLogDebug("[Registration] No need to save installation locally.")
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
			MMLogDebug("[Registration] Sending the registration updates to server...")
			self.sendRegistration()
		} else {
			MMLogDebug("[Registration] No need to send the installation on server.")
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
	
	private func handleRegistrationResult(_ result: MMRegistrationResult) {
		self.context.performAndWait {
			guard let installationObject = self.installationObject else {
				return
			}
			switch result {
			case .Success(let regResponse):
				MMLogDebug("[Registration] Installation updated on server for internal ID \(regResponse.internalUserId). Updating local version...")
				installationObject.resetDirtyRegistration()
				installationObject.internalUserId = regResponse.internalUserId
				self.context.MM_saveToPersistentStoreAndWait()
				NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationRegistrationUpdated, userInfo: [MMNotificationKeyRegistrationInternalId: regResponse.internalUserId])
			case .Failure(let error):
				MMLogError("[Registration] request failed with error: \(error)")
			case .Cancel:
				MMLogError("[Registration] request cancelled.")
			}
		}
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Registration] finished with errors: \(errors)")
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
