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

typealias MMStoreOptions = [NSObject: AnyObject]

struct MMStorageSettings {
	let modelName: String = "MMStorageModel"
	var databaseFileName: String?
	var storeOptions: MMStoreOptions?
	
	static var inMemoryStoreSettings = MMStorageSettings(databaseFileName: nil, storeOptions: nil)
	static var SQLiteStoreSettings = MMStorageSettings(databaseFileName: "MobileMessaging.sqlite", storeOptions: [NSMigratePersistentStoresAutomaticallyOption as NSObject: true as AnyObject, NSInferMappingModelAutomaticallyOption as NSObject: true as AnyObject])
}

final class MMCoreDataStorage {
	
	init(settings: MMStorageSettings) throws {
        self.databaseFileName = settings.databaseFileName
        self.storeOptions = settings.storeOptions
		self.managedObjectModelName = settings.modelName
		try preparePersistentStoreCoordinator()
    }
	
	//MARK: Internal
	func preparePersistentStoreCoordinator() throws {
		_persistentStoreCoordinator = persistentStoreCoordinator
		if _persistentStoreCoordinator == nil {
			throw MMInternalErrorType.StorageInitializationError
		}
	}
	
	class func newInMemoryStorage() throws -> MMCoreDataStorage {
		return try MMCoreDataStorage(settings: MMStorageSettings.inMemoryStoreSettings)
	}
	
	class func SQLiteStorage() throws -> MMCoreDataStorage {
		return try MMCoreDataStorage(settings: MMStorageSettings.SQLiteStoreSettings)
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
	
	func newPrivateContext() -> NSManagedObjectContext {
		let newContext = NSManagedObjectContext.init(concurrencyType: .privateQueueConcurrencyType)
		newContext.persistentStoreCoordinator = persistentStoreCoordinator
		newContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
		newContext.undoManager = nil
		return newContext
	}
	
	func newContextWithNewPSC() throws -> NSManagedObjectContext {
		let newContext = NSManagedObjectContext.init(concurrencyType: .privateQueueConcurrencyType)
		newContext.persistentStoreCoordinator = try newPersistentStoreCoordinator()
		newContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
		newContext.undoManager = nil
		return newContext
	}
	
	func drop() {
		_mainThreadManagedObjectContext = nil
		_managedObjectModel = nil
		_persistentStoreCoordinator = nil
		_persistentStore?.MM_removePersistentStoreFiles()
	}
	
	//MARK: Private
	private let managedObjectModelName: String
    private var managedObjectModelBundle: Bundle {
        return Bundle(for: type(of: self))
	}
    private var databaseFileName: String?
    private var storeOptions: MMStoreOptions?
	
	private func addPersistentStoreWithPath(_ psc: NSPersistentStoreCoordinator, storePath: String?, options: MMStoreOptions?) throws {
        if let storePath = storePath {
            let storeURL = NSURL.fileURL(withPath: storePath)
            do {
                _persistentStore = try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
            } catch let error as NSError {
                let isMigrationError = error.code == NSMigrationError ||
                    error.code == NSMigrationMissingSourceModelError ||
					error.code == NSPersistentStoreIncompatibleVersionHashError
                
                if error.domain == NSCocoaErrorDomain && isMigrationError {
                    MMLogError("Couldn't open the database, because of migration error, database will be recreated")
                    NSPersistentStore.MM_removePersistentStoreFilesAtURL(storeURL)
                    _persistentStore = try psc.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)
                }
            }
        } else {
            _persistentStore = try psc.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        }
    }
	
	private func persistentStoreDirectory(fileName: String) -> String {
        let applicationSupportPaths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let basePath: NSString = applicationSupportPaths.first as NSString? ?? NSTemporaryDirectory() as NSString
        let fm = FileManager.default
		let persistentStoreDir = basePath.appendingPathComponent("com.mobile-messaging.database")
        if (fm.fileExists(atPath: persistentStoreDir) == false) {
            do {
                try fm.createDirectory(atPath: persistentStoreDir, withIntermediateDirectories: true, attributes: nil)
            } catch { }
        }
        return (persistentStoreDir as NSString).appendingPathComponent(fileName)
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
				let momUrl = NSURL.fileURL(withPath: momPath)
				_managedObjectModel = NSManagedObjectModel(contentsOf: momUrl)
			} else {
				MMLogError("Couldn't find managedObjectModel file \(momName)")
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
		MMLogError("Failed creating persistent store: \(error)")
    }
	
    private var _mainThreadManagedObjectContext: NSManagedObjectContext?
}
