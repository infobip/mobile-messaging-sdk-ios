//
//  MMCoreDataStorage.swift
//  MobileMessaging
//
//  Created by Andrey K. on 18/02/16.
//
//

import Foundation
import CoreData

enum MMStorageType {
	case SQLite
	case InMemory
}

typealias MMStoreOptions = [AnyHashable: Any]

struct MMStorageSettings {
	let modelName: String
	var databaseFileName: String?
	var storeOptions: MMStoreOptions?

	static var inMemoryStoreSettings = MMStorageSettings(modelName: "MMInternalStorageModel", databaseFileName: nil, storeOptions: nil)
	static var SQLiteInternalStorageSettings = MMStorageSettings(modelName: "MMInternalStorageModel", databaseFileName: "MobileMessaging.sqlite", storeOptions: defaultStoreOptions)
	static var SQLiteMessageStorageSettings = MMStorageSettings(modelName: "MMMessageStorageModel", databaseFileName: "MessageStorage.sqlite", storeOptions: defaultStoreOptions)
	static var SQLiteChatStorageSettings = MMStorageSettings(modelName: "MMMessageStorageModel", databaseFileName: "ChatStorage.sqlite", storeOptions: defaultStoreOptions)

	static var defaultStoreOptions: MMStoreOptions {
		var result: MMStoreOptions = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
		// by doing this, we stick to old behaviour until we have time to investigate possible issues (i.e. http://stackoverflow.com/questions/39438433/xcode-8-gm-sqlite-error-code6922-disk-i-o-error)
		result[NSPersistentStoreConnectionPoolMaxSizeKey] = 1
		return result
	}
}

final public class MMCoreDataStorage: NamedLogger {

	init(settings: MMStorageSettings) throws {
		self.databaseFileName = settings.databaseFileName
		self.storeOptions = settings.storeOptions
		self.managedObjectModelName = settings.modelName
		try preparePersistentStoreCoordinator()
	}

	//MARK: Internal
	class func makeInMemoryStorage() throws -> MMCoreDataStorage {
		return try MMCoreDataStorage(settings: MMStorageSettings.inMemoryStoreSettings)
	}

	class func makeSQLiteInternalStorage() throws -> MMCoreDataStorage {
		return try MMCoreDataStorage(settings: MMStorageSettings.SQLiteInternalStorageSettings)
	}

	class func makeSQLiteMessageStorage() throws -> MMCoreDataStorage {
		return try MMCoreDataStorage(settings: MMStorageSettings.SQLiteMessageStorageSettings)
	}

	class func makeSQLiteChatStorage() throws -> MMCoreDataStorage {
		return try MMCoreDataStorage(settings: MMStorageSettings.SQLiteChatStorageSettings)
	}

	class func makeInternalStorage(_ type: MMStorageType) throws -> MMCoreDataStorage {
		switch type {
		case .InMemory:
			return try MMCoreDataStorage.makeInMemoryStorage()
		case .SQLite:
			return try MMCoreDataStorage.makeSQLiteInternalStorage()
		}
	}

	class func dropStorages(internalStorage: MMCoreDataStorage, messageStorages: [String: MessageStorageQueuedAdapter]) {
		let storages = [internalStorage] + messageStorages.values.map({ return ($0.adapteeStorage as? MMDefaultMessageStorage)?.coreDataStorage })
		storages.forEach({ $0?.drop() })
	}

	var mainThreadManagedObjectContext: NSManagedObjectContext? {
		guard _mainThreadManagedObjectContext == nil else {
			return _mainThreadManagedObjectContext
		}

		if let coordinator = persistentStoreCoordinator {
			_mainThreadManagedObjectContext = NSManagedObjectContext.init(concurrencyType: .mainQueueConcurrencyType)
			_mainThreadManagedObjectContext?.persistentStoreCoordinator = coordinator
			_mainThreadManagedObjectContext?.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
			_mainThreadManagedObjectContext?.undoManager = nil
		}
		return _mainThreadManagedObjectContext
	}

	public func newPrivateContext() -> NSManagedObjectContext {
		let newContext = NSManagedObjectContext.init(concurrencyType: .privateQueueConcurrencyType)
		newContext.persistentStoreCoordinator = persistentStoreCoordinator
		newContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
		newContext.undoManager = nil
		return newContext
	}

	func drop() {
		_mainThreadManagedObjectContext = nil
		_managedObjectModel = nil
		_persistentStore?.MM_removePersistentStoreFiles()
		if let ps = _persistentStore {
			do {
				try _persistentStoreCoordinator?.remove(ps)
			} catch (let exception) {
				logError("Removing persistent store \(exception)")
			}
		}
		_persistentStoreCoordinator = nil
		_persistentStore = nil
	}

	//MARK: Private
	private let managedObjectModelName: String
	private var managedObjectModelBundle: Bundle {
        return MobileMessaging.resourceBundle
	}
	private var databaseFileName: String?
	private var storeOptions: MMStoreOptions?

	private func preparePersistentStoreCoordinator() throws {
		_persistentStoreCoordinator = persistentStoreCoordinator
		if _persistentStoreCoordinator == nil {
			throw MMInternalErrorType.StorageInitializationError
		}
	}

	//FIXME: align the name with swift guidelines
	private func addPersistentStoreWithPath(_ psc: NSPersistentStoreCoordinator, storePath: String?, options: MMStoreOptions?) throws {
		if let storePath = storePath {
			let storeURL = URL(fileURLWithPath: storePath)
			do {
				logDebug("Adding persistent store at \(storeURL)")
				_persistentStore = try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
				logDebug("Persistent store added successfully")
			} catch let error as NSError {
				logError("Error occured while adding persistent store: \(error)")


				let isMigrationError = error.code == NSMigrationError ||
					error.code == NSMigrationMissingSourceModelError ||
					error.code == NSPersistentStoreIncompatibleVersionHashError ||
					error.code == NSMigrationMissingMappingModelError

				if error.domain == NSCocoaErrorDomain && isMigrationError {
					logError("Couldn't open the database, because of migration error, database will be recreated")
					NSPersistentStore.MM_removePersistentStoreFilesAtURL(storeURL)
					_persistentStore = try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
				}
			}
		} else {
			logDebug("Adding in-memory store")
			_persistentStore = try psc.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
		}
	}

	private func persistentStoreDirectory(fileName: String) -> String {
		let applicationSupportPaths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
		let basePath = applicationSupportPaths.first ?? NSTemporaryDirectory()
		let fm = FileManager.default
		let persistentStoreDir = URL(fileURLWithPath: basePath).appendingPathComponent("com.mobile-messaging.database").path
		if (fm.fileExists(atPath: persistentStoreDir) == false) {
			do {
				try fm.createDirectory(atPath: persistentStoreDir, withIntermediateDirectories: true, attributes: nil)
			} catch { }
		}
		return URL(fileURLWithPath: persistentStoreDir).appendingPathComponent(fileName).path

	}

	private var _managedObjectModel: NSManagedObjectModel?
	private var managedObjectModel: NSManagedObjectModel? {
		get {
			guard _managedObjectModel == nil else {
				return _managedObjectModel
			}

			let momName = managedObjectModelName
			var momPath = managedObjectModelBundle.path(forResource: momName, ofType: "mom")
			if (momPath == nil) {
				momPath = managedObjectModelBundle.path(forResource: momName, ofType: "momd")
			}
			if let momPath = momPath {
				let momUrl = URL(fileURLWithPath: momPath)
				_managedObjectModel = NSManagedObjectModel(contentsOf: momUrl)
			} else {
				logError("Couldn't find managedObjectModel file \(momName)")
			}
			return _managedObjectModel
		}
	}

	private var _persistentStoreCoordinator: NSPersistentStoreCoordinator?
	private var _persistentStore: NSPersistentStore?

	private func newPersistentStoreCoordinator() throws -> NSPersistentStoreCoordinator {
		guard let mom = managedObjectModel else {
			throw MMInternalErrorType.StorageInitializationError
		}

		let newPSC = NSPersistentStoreCoordinator(managedObjectModel: mom)

		if let dbFileName = databaseFileName {
			// SQLite storage
			let storePath = persistentStoreDirectory(fileName: dbFileName)
			do {
				try addPersistentStoreWithPath(newPSC, storePath: storePath, options: storeOptions)
			} catch let error as NSError {
				didNotAddPersistentStoreWithPath(storePath, options: storeOptions, error: error)
				throw MMInternalErrorType.StorageInitializationError
			}
		} else {
			// in-memory storage
			do {
				try addPersistentStoreWithPath(newPSC, storePath: nil, options: storeOptions)
			} catch let error as NSError {
				didNotAddPersistentStoreWithPath(nil, options: storeOptions, error: error)
				throw MMInternalErrorType.StorageInitializationError
			}
		}

		return newPSC
	}

	private var persistentStoreCoordinator: NSPersistentStoreCoordinator? {
		get {
			if _persistentStoreCoordinator != nil {
				return _persistentStoreCoordinator
			}

			if let psc = try? newPersistentStoreCoordinator() {
				_persistentStoreCoordinator = psc
			}

			return _persistentStoreCoordinator
		}
	}

	private func didNotAddPersistentStoreWithPath(_ storePath: String?, options: MMStoreOptions?, error: NSError?) {
		logError("Failed creating persistent store: \(error.orNil)")
	}

	private var _mainThreadManagedObjectContext: NSManagedObjectContext?
}
