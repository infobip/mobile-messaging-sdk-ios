//
//  MMInstallationManager.swift
//  Pods
//
//  Created by Andrey K. on 18/04/16.
//
//

import Foundation
import CoreData

final class MMInstallationManager {
	//MARK: Internal
	var registrationRemoteAPI: MMRemoteAPIQueue
	lazy var registrationQueue = OperationQueue.mm_newSerialQueue
	var storage: MMCoreDataStorage
	var storageContext: NSManagedObjectContext
	
	init(storage: MMCoreDataStorage, registrationRemoteAPI: MMRemoteAPIQueue) {
		self.registrationRemoteAPI = registrationRemoteAPI
		self.emailMsisdnRemoteAPI = MMRemoteAPIQueue(baseURL: registrationRemoteAPI.baseURL, applicationCode: registrationRemoteAPI.applicationCode)
		self.storage = storage
		self.storageContext = storage.newPrivateContext()
		_currentInstallation = installationObject
	}
	
	func getValueForKey(key: String) -> AnyObject? {
		var result: AnyObject?
		storageContext.performBlockAndWait {
			result = self.installationObject.valueForKey(key)
		}
		return result
	}
	
	func setValueForKey(key: String, value: AnyObject?) {
		storageContext.performBlock {
			self.installationObject.setValueIfDifferent(value, forKey: key)
		}
	}
	
    func syncWithServer(completion: (NSError? -> Void)? = nil) {
        let newRegOp = RegistrationOperation(context: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion)
        registrationQueue.addOperation(newRegOp)
    }
    
	func updateDeviceToken(token: NSData, completion: (NSError? -> Void)? = nil) {
		let newRegOp = RegistrationOperation(newDeviceToken: token, context: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion)
		registrationQueue.addOperation(newRegOp)
	}
	
	func saveMsisdn(msisdn: String, completion: (NSError?) -> Void) {
		registrationQueue.addOperation(SetMSISDNOperation(msisdn: msisdn, context: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion))
	}
	
	func saveEmail(email: String, completion: (NSError?) -> Void) {
		registrationQueue.addOperation(SetEmailOperation(email: email, context: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion))
	}
	
	func save(completion: (() -> Void)? = nil) {
		storageContext.performBlock {
			self.storageContext.MM_saveToPersistentStoreAndWait()
			completion?()
		}
	}

	var installationObject: InstallationManagedObject {
		if let installation = _currentInstallation {
			return installation
		} else {
			_currentInstallation = fetchOrCreateCurrentInstallation()
			return _currentInstallation!
		}
	}
	
	//MARK: Private
	private var installationHasChanges: Bool {
		return installationObject.changedValues().count > 0
	}
	private var emailMsisdnRemoteAPI: MMRemoteAPIQueue
	private var _currentInstallation: InstallationManagedObject?
	
	
	private func fetchOrCreateCurrentInstallation() -> InstallationManagedObject {
		if let existingInstallation = findCurrentInstallation() {
			return existingInstallation
		} else {
			return createInstallation()
		}
	}
	
	private func createInstallation() -> InstallationManagedObject {
		var result: InstallationManagedObject?
		storageContext.performBlockAndWait {
			result = InstallationManagedObject.MM_createEntityInContext(context: self.storageContext)
			self.storageContext.MM_saveToPersistentStoreAndWait()
		}
		return result!
	}
	
	private func findCurrentInstallation() -> InstallationManagedObject? {
		var result: InstallationManagedObject?
		storageContext.performBlockAndWait {
			result = InstallationManagedObject.MM_findFirstInContext(self.storageContext)
		}
		return result
	}
	
}