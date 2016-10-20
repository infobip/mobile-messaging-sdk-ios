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
	
	//FIXME: duplication of setValueForKey methods
	func setValueForKey<Value: Equatable>(_ key: String, value: Value?) {
		storageContext.perform {
			self.installationObject.setValueIfDifferent(value, forKey: key)
		}
	}
	
	func setValueForKey(_ key: String, value: [AnyHashable: UserDataFoundationTypes]? ) {
		storageContext.perform {
			self.installationObject.setValueIfDifferent(value, forKey: key)
		}
	}
	
	func set(_ value: UserDataFoundationTypes?, key: AnyHashable, attribute: String) {
		storageContext.perform {
			var dictValue : [AnyHashable : UserDataFoundationTypes]? = [key: value ?? NSNull()]
			if let dictionaryValue = self.getValueForKey(attribute) as? [AnyHashable : UserDataFoundationTypes] {
				dictValue = dictionaryValue + dictValue
			}
			self.installationObject.setValueIfDifferent(dictValue, forKey: attribute)
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
