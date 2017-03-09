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
	lazy var registrationQueue = MMOperationQueue.newSerialQueue
	let storage: MMCoreDataStorage
	let storageContext: NSManagedObjectContext
	let mmContext: MobileMessaging?
	
	deinit {
		registrationQueue.cancelAllOperations()
	}
	
	init(storage: MMCoreDataStorage, mmContext: MobileMessaging?) {
		self.storage = storage
		self.storageContext = storage.newPrivateContext()
		self.mmContext = mmContext
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
	
	func syncInstallationWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		guard let mmContext = mmContext else {
			completion?(NSError(type: MMInternalErrorType.UnknownError))
			return
		}
		MMLogDebug("[Installation management] sync installation with server")
		let newRegOp = InstallationDataSynchronizationOperation(context: storageContext, mmContext: mmContext, finishBlock: completion)
		registrationQueue.addOperation(newRegOp)
	}
	
	func sendSystemDataToServer(_ completion: ((NSError?) -> Void)? = nil) {
		guard let mmContext = mmContext else {
			completion?(NSError(type: MMInternalErrorType.UnknownError))
			return
		}
		MMLogDebug("[Installation management] send system data to server")
		let op = SystemDataSynchronizationOperation(сontext: storageContext, mmContext: mmContext, finishBlock: completion)
		registrationQueue.addOperation(op)
	}
	
	func syncUserDataWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		guard let mmContext = mmContext else {
			completion?(NSError(type: MMInternalErrorType.UnknownError))
			return
		}
		MMLogDebug("[Installation management] sync user data with server")
		let op = UserDataSynchronizationOperation(syncOperationWithContext: storageContext, mmContext: mmContext, finishBlock: completion)
		registrationQueue.addOperation(op)
	}
	
	func fetchUserWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		guard let mmContext = mmContext else {
			completion?(NSError(type: MMInternalErrorType.UnknownError))
			return
		}
		MMLogDebug("[Installation management] fetch user with server")
		let op = UserDataSynchronizationOperation(fetchingOperationWithContext: storageContext, mmContext: mmContext, finishBlock: completion)
		registrationQueue.addOperation(op)
	}
	
	func updateRegistrationEnabledStatus(withValue value: Bool, completion: ((NSError?) -> Void)? = nil) {
		storageContext.performAndWait {
			self.installationObject.setRegistrationEnabledIfDifferent(flag: value)
		}
		syncInstallationWithServer(completion)
	}
	
	func updateDeviceToken(token: Data, completion: ((NSError?) -> Void)? = nil) {
		storageContext.performAndWait {
			self.installationObject.setDeviceTokenIfDifferent(token: token.mm_toHexString)
		}
		syncInstallationWithServer(completion)
	}
	
	func save(_ completion: ((Void) -> Void)? = nil) {
		storageContext.perform {
			self.storageContext.MM_saveToPersistentStoreAndWait()
			completion?()
		}
	}
	
	func resetContext() {
		storageContext.perform {
			self.storageContext.rollback()
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
