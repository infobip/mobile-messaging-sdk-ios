//
//  MMInstallationManager.swift
//
//  Created by Andrey K. on 18/04/16.
//
//

import Foundation
import CoreData

protocol InstallationDataProvider {
	func getValueForKey(_ key: String) -> Any?
	func setValueForKey<Value: Equatable>(_ key: String, value: Value?)
	func setValueForKey(_ key: String, value: [AnyHashable: UserDataFoundationTypes]? )
	func set(_ value: UserDataFoundationTypes?, key: AnyHashable, attribute: String)
	func resetChanges()
	func persist()

	func resetDirtyAttribute(_ attributes: AttributesSet)
	func isAttributeDirty(_ attributes: AttributesSet) -> Bool
}

class InMemoryDataProvider: InstallationDataProvider {
	var storage: [AnyHashable: Any] = [:]
	
	func resetDirtyAttribute(_ attributes: AttributesSet) {
		return
	}
	
	func isAttributeDirty(_ attributes: AttributesSet) -> Bool {
		return true
	}
	
	func getValueForKey(_ key: String) -> Any? {
		return storage[key]
	}
	
	func setValueForKey<Value: Equatable>(_ key: String, value: Value?) {
		storage[key] = value
	}
	
	func setValueForKey(_ key: String, value: [AnyHashable: UserDataFoundationTypes]? ) {
		storage[key] = value
	}
	
	func set(_ value: UserDataFoundationTypes?, key: AnyHashable, attribute: String) {
		var dictValue: [AnyHashable: UserDataFoundationTypes]? = [key: value ?? NSNull()]
		if let dictionaryValue = self.getValueForKey(attribute) as? [AnyHashable : UserDataFoundationTypes] {
			dictValue = dictionaryValue + dictValue
		}
		storage[attribute] = dictValue
	}
	
	func resetChanges() {
		return
	}
	
	func persist() {
		return
	}
}

class CoreDataProvider: InstallationDataProvider {
	let coreDataStorage: MMCoreDataStorage
	let context: NSManagedObjectContext
	
	required init(storage: MMCoreDataStorage) {
		self.coreDataStorage = storage
		self.context = storage.newPrivateContext()
	}
	
	func resetDirtyAttribute(_ attributes: AttributesSet) {
		context.performAndWait {
			self.installationObject.resetDirtyAttribute(attributes: attributes)
		}
	}
	
	func isAttributeDirty(_ attributes: AttributesSet) -> Bool {
		var result: Bool = false
		context.performAndWait {
			result = self.installationObject.dirtyAttributesSet.intersection(attributes).isEmpty == false
		}
		return result
	}
	
	func getValueForKey(_ key: String) -> Any? {
		var result: Any?
		context.performAndWait {
			result = self.installationObject.value(forKey: key)
		}
		return result
	}
	
	func setValueForKey<Value: Equatable>(_ key: String, value: Value?) {
		context.performAndWait {
			self.installationObject.setValueIfDifferent(value, forKey: key)
		}
	}
	
	func setValueForKey(_ key: String, value: [AnyHashable: UserDataFoundationTypes]? ) {
		context.performAndWait {
			self.installationObject.setValueIfDifferent(value, forKey: key)
		}
	}
	
	func set(_ value: UserDataFoundationTypes?, key: AnyHashable, attribute: String) {
		context.performAndWait {
			var dictValue: [AnyHashable: UserDataFoundationTypes]? = [key: value ?? NSNull()]
			if let dictionaryValue = self.getValueForKey(attribute) as? [AnyHashable : UserDataFoundationTypes] {
				dictValue = dictionaryValue + dictValue
			}
			self.installationObject.setValueIfDifferent(dictValue, forKey: attribute)
		}
	}
	
	func resetChanges() {
		context.reset()
	}
	
	func persist() {
		context.MM_saveToPersistentStoreAndWait()
	}
	
	//MARK: Private
	private var installationObject: InstallationManagedObject {
		if let installation = _currentInstallation {
			return installation
		} else {
			_currentInstallation = fetchOrCreateCurrentInstallation()
			return _currentInstallation!
		}
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
		context.performAndWait {
			result = InstallationManagedObject.MM_createEntityInContext(context: self.context)
			self.context.MM_saveToPersistentStoreAndWait()
		}
		return result!
	}
	
	private func findCurrentInstallation() -> InstallationManagedObject? {
		var result: InstallationManagedObject?
		context.performAndWait {
			result = InstallationManagedObject.MM_findFirstInContext(self.context)
		}
		return result
	}
}
