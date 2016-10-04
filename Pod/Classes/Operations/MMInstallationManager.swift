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
	
	func getValueForKey(_ key: String) -> Any? {
		var result: Any?
		storageContext.performAndWait {
			result = self.installationObject.value(forKey: key)
		}
		return result
	}
	
	//FIXME: duplication in setValueForKey
	func setValueForKey<Value: Equatable>(_ key: String, value: Value?) {
		storageContext.perform {
			if let dictValue = value as? [AnyHashable : UserDataSupportedTypes] {
				if var dictionaryValue = self.getValueForKey(key) as? [AnyHashable : UserDataSupportedTypes] {
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
	
	//FIXME: duplication in setValueForKey
	func setValueForKey(_ key: String, value: [AnyHashable : UserDataSupportedTypes]?) {
		storageContext.perform {
			if let dictValue = value {
				if var dictionaryValue = self.getValueForKey(key) as? [AnyHashable : UserDataSupportedTypes] {
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
	
    func syncRegistrationWithServer(_ completion: ((NSError?) -> Void)? = nil) {
        let newRegOp = RegistrationOperation(context: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion)
        registrationQueue.addOperation(newRegOp)
    }
	
	func fetchUserWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		let op = UserDataSynchronizationOperation(fetchingOperationWithContext: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion)
		registrationQueue.addOperation(op)
	}
	
	func syncUserWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		let op = UserDataSynchronizationOperation(syncOperationWithContext: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion)
		registrationQueue.addOperation(op)
	}
	
	func updateDeviceToken(token: Data, completion: ((NSError?) -> Void)? = nil) {
		let newRegOp = RegistrationOperation(newDeviceToken: token, context: storageContext, remoteAPIQueue: registrationRemoteAPI, finishBlock: completion)
		registrationQueue.addOperation(newRegOp)
		syncUserWithServer()
	}
	
	func save(_ completion: ((Void) -> Void)? = nil) {
		storageContext.perform {
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
		storageContext.performAndWait {
			result = InstallationManagedObject.MM_createEntityInContext(context: self.storageContext)
			self.storageContext.MM_saveToPersistentStoreAndWait()
		}
		return result!
	}
	
	private func findCurrentInstallation() -> InstallationManagedObject? {
		var result: InstallationManagedObject?
		storageContext.performAndWait {
			result = InstallationManagedObject.MM_findFirstInContext(self.storageContext)
		}
		return result
	}
	
}
