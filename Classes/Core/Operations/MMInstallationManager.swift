//
//  InstallationDataServiceManager.swift
//
//  Created by Andrey K. on 18/04/16.
//
//

import Foundation
import CoreData

protocol InstallationDataProvider {
	func getValueForKey(_ key: String) -> Any?
	func set(value: Any?, forAttribute att: Attributes)
	func set(nestedValue value: AttributeType?, forAttribute att: Attributes)
	func resetChanges()
	func persist()

	var dirtyAttributesSet: AttributesSet {get}
	func resetDirtyAttribute(_ attributes: Attributes)
	func isAttributeDirty(_ attributes: Attributes) -> Bool
}

class InMemoryDataProvider: InstallationDataProvider {
	var storage: [String: Any] = [:]

	var dirtyAttributesSet: AttributesSet {
		return AttributesSet()//not implemented
	}

	func resetDirtyAttribute(_ attributes: Attributes) {
		return
	}
	
	func isAttributeDirty(_ attributes: Attributes) -> Bool {
		return true
	}
	
	func getValueForKey(_ key: String) -> Any? {
		return storage[key]
	}
	
	func set(value: Any?, forAttribute att: Attributes) {
		storage[att.rawValue] = value
	}

	func set(nestedValue value: AttributeType?, forAttribute att: Attributes) {
		let attribute = att.databaseKey
		guard let key = att.key else {
			return
		}
		var dictValue: [String: AttributeType]? = [key: value ?? NSNull()]
		if let dictionaryValue = self.getValueForKey(attribute) as? [String : AttributeType] {
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

	var dirtyAttributesSet: AttributesSet {
		var result: AttributesSet = AttributesSet()
		context.performAndWait {
			result = self.installationObject.dirtyAttsSet
		}
		return result
	}

	func resetDirtyAttribute(_ attributes: Attributes) {
		context.performAndWait {
			self.installationObject.resetDirtyAttribute(attributes: attributes)
		}
	}
	
	func isAttributeDirty(_ attributes: Attributes) -> Bool {
		var result: Bool = false
		context.performAndWait {
			result = self.installationObject.dirtyAttsSet.contains(attributes)
		}
		return result
	}
	
	func getValueForKey(_ key: String) -> Any? {
		var result: Any?
		context.performAndWait {
			result = self.installationObject.value(forKey: key)
		}
		switch result {
		case (let n as NSNumber) where n.isBool:
			result = n.boolValue
		default: break;
		}
		return result
	}
	
	func set(value: Any?, forAttribute att: Attributes) {
		context.performAndWait {
			self.installationObject.setValue(value, forKey: att.databaseKey)
		}
	}

	func set(nestedValue value: AttributeType?, forAttribute att: Attributes) {
		let attribute = att.databaseKey
		guard let key = att.key else {
			return
		}
		context.performAndWait {
			var dictValue: [String: AttributeType]? = [key: value ?? NSNull()]
			if let dictionaryValue = self.getValueForKey(attribute) as? [String : AttributeType] {
				dictValue = dictionaryValue + dictValue
			}
			self.installationObject.setValue(dictValue, forKey: att.rawValue)
		}
	}
	
	func resetChanges() {
		context.reset()
	}
	
	func persist() {
		context.MM_saveToPersistentStoreAndWait()
	}

	//MARK: Private
	var installationObject: InstallationManagedObject {
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
