//
//  MMInstallationManager.swift
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
	let storage: MMCoreDataStorage
	let storageContext: NSManagedObjectContext

	deinit {
		registrationQueue.cancelAllOperations()
	}
	
	init(storage: MMCoreDataStorage, registrationRemoteAPI: MMRemoteAPIQueue) {
		self.registrationRemoteAPI = registrationRemoteAPI
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
			if let dictValue = value as? [String: AnyObject] {
				if var dictionaryValue = self.getValueForKey(key) as? [String: AnyObject] {
					dictionaryValue += dictValue
					self.installationObject.setValueIfDifferent(dictionaryValue, forKey: key)
				} else {
					self.installationObject.setValueIfDifferent(value, forKey: key)
				}
			} else {
				self.installationObject.setValueIfDifferent(value, forKey: key)
			}
		}
	}
	
    func syncRegistrationWithServer(completion: (NSError? -> Void)? = nil) {
        let newRegOp = RegistrationOperation(context: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion)
        registrationQueue.addOperation(newRegOp)
    }
	
	func fetchUserWithServer(completion: (NSError? -> Void)? = nil) {
		let op = UserDataSynchronizationOperation(fetchingOperationWithContext: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion)
		registrationQueue.addOperation(op)
	}
	
	func syncUserWithServer(completion: (NSError? -> Void)? = nil) {
		let op = UserDataSynchronizationOperation(syncOperationWithContext: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion)
		registrationQueue.addOperation(op)
	}
	
	func updateDeviceToken(token: NSData, completion: (NSError? -> Void)? = nil) {
		let newRegOp = RegistrationOperation(newDeviceToken: token, context: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion)
		registrationQueue.addOperation(newRegOp)
		syncUserWithServer()
	}
	
	func save(completion: (Void -> Void)? = nil) {
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
			result = InstallationManagedObject.MM_findFirstInContext(context: self.storageContext)
		}
		return result
	}
	
}