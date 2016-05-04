//
//  MMCoreDataStorage.swift
//  MobileMessaging
//
//  Created by Andrey K. on 18/02/16.
//  
//

import Foundation
import CoreData

class MMStoringService {
	init(storage: MMCoreDataStorage) {
		self.storage = storage
	}
	
	//MARK: Internal
	var storageContext: NSManagedObjectContext {
		if let moc = _storageContext {
			return moc
		} else {
			if let coordinator = storage.persistentStoreCoordinator {
				_storageContext = NSManagedObjectContext.init(concurrencyType: .PrivateQueueConcurrencyType)
				_storageContext?.persistentStoreCoordinator = coordinator
				_storageContext?.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
				_storageContext?.undoManager = nil
			}
		}
		return _storageContext!
	}
	
	func save(completion: (() -> Void)? = nil) {
		_storageContext?.performBlock {
			self.storageContext.MR_saveOnlySelfAndWait()
			completion?()
		}
	}
	
	var storage: MMCoreDataStorage
	
	//MARK: Private
	private var _storageContext: NSManagedObjectContext?
}

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
	static var SQLiteStoreSettings = MMStorageSettings(databaseFileName: "MobileMessaging.sqlite", storeOptions: [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true])
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
			_mainThreadManagedObjectContext = NSManagedObjectContext.init(concurrencyType: .MainQueueConcurrencyType)
			_mainThreadManagedObjectContext?.persistentStoreCoordinator = coordinator
			_mainThreadManagedObjectContext?.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
			_mainThreadManagedObjectContext?.undoManager = nil
		}
		return _mainThreadManagedObjectContext
	}
	
	func newParallelContext() throws -> NSManagedObjectContext {
		let newContext = NSManagedObjectContext.init(concurrencyType: .PrivateQueueConcurrencyType)
		newContext.persistentStoreCoordinator = try newPersistentStoreCoordinator()
		newContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
		newContext.undoManager = nil
		return newContext
	}
	
	func drop() {
		_persistentStore?.MR_removePersistentStoreFiles()
	}
	
	//MARK: Private
	private let managedObjectModelName: String
    private var managedObjectModelBundle: NSBundle {
        return NSBundle(forClass: self.dynamicType)
	}
    private var databaseFileName: String?
    private var storeOptions: MMStoreOptions?
	
	private func addPersistentStoreWithPath(psc: NSPersistentStoreCoordinator, storePath: String?, options: MMStoreOptions?) throws {
        if let storePath = storePath {
            let storeURL = NSURL.fileURLWithPath(storePath)
            do {
                _persistentStore = try psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: options)
            } catch let error as NSError {
                let isMigrationError = error.code == NSMigrationError ||
                    error.code == NSMigrationMissingSourceModelError
                error.code == NSPersistentStoreIncompatibleVersionHashError
                
                if error.domain == NSCocoaErrorDomain && isMigrationError {
                    MMLogInfo("Couldn't open the database, because of migration error, database will be recreated")
                    NSPersistentStore.MR_removePersistentStoreFilesAtURL(storeURL)
                    _persistentStore = try psc.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: options)
                }
            }
        } else {
            _persistentStore = try psc.addPersistentStoreWithType(NSInMemoryStoreType, configuration: nil, URL: nil, options: nil)
        }
    }
	
    private var persistentStoreDirectory: NSString {
        let paths = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true)
        let basePath: NSString = paths.count > 0 ? paths[0] : NSTemporaryDirectory()
        let fm = NSFileManager.defaultManager()
        let bundleIdentifier = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleIdentifier") as? String
        let persistentStoreDir = basePath.stringByAppendingPathComponent(bundleIdentifier ?? "default")
        if (fm.fileExistsAtPath(persistentStoreDir) == false) {
            do {
                try fm.createDirectoryAtPath(persistentStoreDir, withIntermediateDirectories: true, attributes: nil)
            } catch { }
        }
        return persistentStoreDir
    }
	
    private var _managedObjectModel: NSManagedObjectModel?
    private var managedObjectModel: NSManagedObjectModel? {
        get {
			guard _managedObjectModel == nil else {
				return _managedObjectModel
			}
			
			let momName = managedObjectModelName
			var momPath = managedObjectModelBundle.pathForResource(momName, ofType: "mom")
			if (momPath == nil) {
				momPath = managedObjectModelBundle.pathForResource(momName, ofType: "momd")
			}
			if let momPath = momPath {
				let momUrl = NSURL.fileURLWithPath(momPath)
				_managedObjectModel = NSManagedObjectModel(contentsOfURL: momUrl)
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
			let docsPath = persistentStoreDirectory
			let storePath = docsPath.stringByAppendingPathComponent(dbFileName)
			
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
	
    private func didNotAddPersistentStoreWithPath(storePath: NSString?, options: MMStoreOptions?, error: NSError?) {
		MMLogError("Failed creating persistent store: \(error)")
    }
	
    private var _mainThreadManagedObjectContext: NSManagedObjectContext?
}
