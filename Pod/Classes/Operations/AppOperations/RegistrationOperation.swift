//
//  RegistrationOperation.swift
//
//  Created by Andrey K. on 18/04/16.
//
//

import UIKit
import CoreData

final class SyncRegistrationOperation: Operation {
	let context: NSManagedObjectContext
	var installationObject: InstallationManagedObject!
	let finishBlock: ((NSError?) -> Void)?
	
    init(context: NSManagedObjectContext, finishBlock: ((NSError?) -> Void)?) {
		self.context = context
		self.finishBlock = finishBlock
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Registration] Started...")
		context.perform {
			guard let installation = InstallationManagedObject.MM_findFirstInContext(self.context) else {
				self.finish()
				return
			}
			
			self.installationObject = installation
            
			self.sendRegistrationIfNeeded()
		}
	}
    
	private var registrationStatusChanged: Bool {
		return !installationObject.dirtyAttributesSet.intersection(SyncableAttributesSet.isRegistrationEnabled).isEmpty
	}
	
	private func sendRegistrationIfNeeded() {
		MMLogDebug("[Registration] Posting registration to server...")
		self.sendRegistration()
	}
	
	private func sendRegistration() {
        guard let deviceToken = installationObject.deviceToken else {
			MMLogDebug("[Registration] There is no device token. Finishing...")
            self.finish([NSError(type: MMInternalErrorType.UnknownError)])
            return
        }
		
		let isPushRegistrationEnabled: Bool? = registrationStatusChanged ? installationObject.isRegistrationEnabled : nil // send value only if changed
		MobileMessaging.sharedInstance?.remoteApiManager.syncRegistration(internalId: installationObject.internalUserId, deviceToken: deviceToken, isEnabled: isPushRegistrationEnabled) { result in
			self.handleRegistrationResult(result)
			self.finishWithError(result.error)
		}
	}
	
	private func handleRegistrationResult(_ result: RegistrationResult) {
		self.context.performAndWait {
			guard let installationObject = self.installationObject else {
				return
			}
			switch result {
			case .Success(let regResponse):
				MMLogDebug("[Registration] Installation updated on server for internal ID \(regResponse.internalId). Updating local version...")
				if (regResponse.isEnabled != installationObject.isRegistrationEnabled) {
					MobileMessaging.sharedInstance?.updateRegistrationEnabledSubservicesStatus(isPushRegistrationEnabled: regResponse.isEnabled)
				}
				
				installationObject.internalUserId = regResponse.internalId
				installationObject.isRegistrationEnabled = regResponse.isEnabled
				
				installationObject.resetDirtyRegistration()
 				self.context.MM_saveToPersistentStoreAndWait()
				NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationRegistrationUpdated, userInfo: [MMNotificationKeyRegistrationInternalId: regResponse.internalId])
			case .Failure(let error):
				MMLogError("[Registration] request failed with error: \(error)")
			case .Cancel:
				MMLogError("[Registration] request cancelled.")
			}
		}
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Registration] finished with errors: \(errors)")
		finishBlock?(errors.first)
	}
}
