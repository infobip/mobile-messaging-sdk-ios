//
//  MMCoreDataExtensions.swift
//
//  Created by Andrey K. on 18/05/16.
//
//

import CoreData

struct MMContextSaveOptions: OptionSetType {
	let rawValue : Int
	init(rawValue: Int) { self.rawValue = rawValue }
	static let SaveSynchronously	= MMContextSaveOptions(rawValue: 1 << 0)
	static let SaveParent		= MMContextSaveOptions(rawValue: 1 << 1)
}

extension NSManagedObject {
	
	class var MM_entityName: String {
		return NSStringFromClass(self).componentsSeparatedByString(".").last!
	}
	
	class func MM_requestAll(predicate: NSPredicate? = nil) -> NSFetchRequest {
		let r = NSFetchRequest(entityName: self.MM_entityName)
		r.predicate = predicate
		return r
	}
	
	class func MM_executeRequest(request: NSFetchRequest, inContext ctx: NSManagedObjectContext) -> [NSManagedObject]? {
		var results: [NSManagedObject]?
		let requestBlock = {
			do {
				results = try ctx.executeFetchRequest(request) as? [NSManagedObject]
			}
			catch let error as NSError {
				MMLogError("Fetching error: \(error)")
			}
		}
		if ctx.concurrencyType == NSManagedObjectContextConcurrencyType.ConfinementConcurrencyType {
			requestBlock()
		} else {
			ctx.performBlockAndWait(requestBlock)
		}
		return results
	}
	
	class func MM_findAllWithPredicate(predicate: NSPredicate? = nil, inContext context: NSManagedObjectContext) -> [NSManagedObject]? {
		let r = self.MM_requestAll(predicate)
		return self.MM_executeRequest(r, inContext: context)
	}
	
	class func MM_entityDescription(inContext context: NSManagedObjectContext) -> NSEntityDescription {
		return NSEntityDescription.entityForName(self.MM_entityName, inManagedObjectContext: context)!
	}
	
	class func MM_createEntityInContext(entityDescription: NSEntityDescription? = nil, context: NSManagedObjectContext) -> Self {
		let entity = entityDescription ?? self.MM_entityDescription(inContext: context)
		let managedObject = self.init(entity: entity, insertIntoManagedObjectContext: context)
		managedObject.MM_awakeFromCreation()
		return managedObject
	}
	
	func MM_awakeFromCreation() {

	}
	
	var MM_isEntityDeleted: Bool {
		return deleted || managedObjectContext == nil
	}

	func MM_deleteEntityInContext(context: NSManagedObjectContext) -> Bool {
		do {
			let objectInContext = try context.existingObjectWithID(objectID)
			context.deleteObject(objectInContext)
			return objectInContext.MM_isEntityDeleted
		} catch let error as NSError {
			MMLogError("An error occured while deleting an object \(self): \(error)")
		}
		return false
	}

	class func MM_deleteAllMatchingPredicate(predicate: NSPredicate, inContext context: NSManagedObjectContext) {
		let request = self.MM_requestAll(predicate)
		request.returnsObjectsAsFaults = true
		request.includesPropertyValues = false
		
		if let objectsToTruncate = MM_executeRequest(request, inContext: context) {
			for obj in objectsToTruncate {
				obj.MM_deleteEntityInContext(context)
			}
		}
	}
	
	class func MM_executeFetchRequestAndReturnFirstObject<T>(request: NSFetchRequest, inContext context: NSManagedObjectContext) -> T? {
		request.fetchLimit = 1
		let results = MM_executeRequest(request, inContext: context)
		return results?.first as? T
	}

	class func MM_findFirstInContext(predicate: NSPredicate? = nil, context: NSManagedObjectContext) -> Self? {
		let request = MM_requestAll(predicate)
		return MM_executeFetchRequestAndReturnFirstObject(request, inContext: context)
	}
	
	class func MM_findAllInContext(context: NSManagedObjectContext) -> [NSManagedObject]? {
		return MM_findAllWithPredicate(inContext: context)
	}
	
	class func MM_countOfEntitiesWithContext(context: NSManagedObjectContext) -> Int {
		return MM_countOfEntitiesWithPredicate(inContext: context)
	}
	
	class func MM_countOfEntitiesWithPredicate(predicate: NSPredicate? = nil, inContext context: NSManagedObjectContext) -> Int {
		var error: NSError? = nil
		let count = context.countForFetchRequest(MM_requestAll(predicate), error: &error)
		if let error = error {
			MMLogError(error.description)
		}
		return count
	}
	
	class func MM_selectAttribute(attribute: String, withPredicte predicate: NSPredicate, inContext context: NSManagedObjectContext) -> [String: AnyObject]? {
		let request = self.MM_requestAll(predicate)
		request.resultType = .DictionaryResultType
		request.propertiesToFetch = [attribute]
		
		if let results = MM_executeRequest(request, inContext: context) {
			let foundationArray = NSArray(array: results)
			return foundationArray.valueForKeyPath(NSString(format: "@unionOfObjects.%@", attribute) as String) as? [String: AnyObject]
		} else {
			return nil
		}
	}
}

let kMMNSManagedObjectContextWorkingName = "kNSManagedObjectContextWorkingName"

extension NSManagedObjectContext {
	
	func MM_saveWithOptions(options: MMContextSaveOptions, completion: ((Bool, NSError?) -> Void)?) {
		let saveParentContexts = options.contains(.SaveParent)
		let saveSynchronously = options.contains(.SaveSynchronously)
		var ctxHasChanges: Bool = false
		if concurrencyType == NSManagedObjectContextConcurrencyType.ConfinementConcurrencyType {
			ctxHasChanges = hasChanges
		} else {
			performBlockAndWait{ ctxHasChanges = self.hasChanges }
		}
		
		if hasChanges == false {
			MMLogInfo("NO CHANGES IN ** \(MM_workingName) ** CONTEXT - NOT SAVING")
			if (saveParentContexts && parentContext != nil) {
				MMLogVerbose("Proceeding to save parent context \(parentContext?.MM_description)")
			} else {
				completion?(true, nil)
				return
			}
		}
		
		let saveBlock = {
			var optionsSummary = ""
			optionsSummary = optionsSummary.stringByAppendingString(saveParentContexts ? "Save Parents" : "")
			optionsSummary = optionsSummary.stringByAppendingString(saveSynchronously ? "Sync Save" : "")
			
			MMLogVerbose("→ Saving \(self.MM_description) [\(optionsSummary)]")
			
			var error: NSError?
			var saved = false
			do {
				try self.save()
				saved = true
			} catch let err as NSError {
				error = err
				MMLogError("Unable to perform save: \(err)")
			} catch {
				MMLogError("Unable to perform save. Unknown exception.")
			}
			defer {
				if saved == false {
					completion?(saved, error)
				} else {
					// If we should not save the parent context, or there is not a parent context to save (root context), call the completion block
					if let parentCtx = self.parentContext where saveParentContexts {
						let parentContentSaveOptions: MMContextSaveOptions = [.SaveSynchronously, .SaveParent]
						parentCtx.MM_saveWithOptions(parentContentSaveOptions, completion:completion)
					} else {
						// If we are not the default context (And therefore need to save the root context, do the completion action if one was specified
						MMLogInfo("→ Finished saving: \(self.MM_description)")
						
						let numberOfInsertedObjects = self.insertedObjects.count
						let numberOfUpdatedObjects = self.updatedObjects.count
						let numberOfDeletedObjects = self.deletedObjects.count
						
						MMLogVerbose("Objects - Inserted \(numberOfInsertedObjects), Updated \(numberOfUpdatedObjects), Deleted \(numberOfDeletedObjects)")
						completion?(saved, error)
					}
				}
			}
		}
		
		if concurrencyType == NSManagedObjectContextConcurrencyType.ConfinementConcurrencyType {
			saveBlock()
		} else if saveSynchronously == true {
			performBlockAndWait(saveBlock)
		} else {
			performBlock(saveBlock)
		}
	}
	
	var MM_workingName: String {
		return (userInfo.objectForKey(kMMNSManagedObjectContextWorkingName) as? String) ?? "UNNAMED"
	}
	
	var MM_description: String {
		let thread = NSThread.isMainThread() ? "*** MAIN THREAD ***" : "*** BACKGROUND THREAD ***";
		return "\(MM_workingName) on \(thread)"
	}
	
	func MM_saveToPersistentStoreAndWait() {
		MM_saveWithOptions([.SaveParent, .SaveSynchronously], completion: nil)
	}
	
	func MM_saveOnlySelfAndWait() {
		MM_saveWithOptions([.SaveSynchronously], completion: nil)
	}
}

extension NSPersistentStore {
	func MM_removePersistentStoreFiles() -> Bool {
		guard let url = self.URL else {
			return false
		}
		return NSPersistentStore.MM_removePersistentStoreFilesAtURL(url)
	}
	
	class func MM_removePersistentStoreFilesAtURL(url: NSURL) -> Bool {
		guard url.fileURL else {
			assertionFailure("URL must be a file URL")
			return false
		}
		
		let rawURL = url.absoluteString
		
		let shmSidecar = NSURL(string: rawURL.stringByAppendingString("-shm"))!
		let walSidecar = NSURL(string: rawURL.stringByAppendingString("-wal"))!
		
		var removeItemResult = true
		
		for fileURL in [url, shmSidecar, walSidecar] {
			do {
				try NSFileManager.defaultManager().removeItemAtURL(fileURL)
			} catch let error as NSError where error.code == NSFileNoSuchFileError {
				// If the file doesn't exist, that's OK — that's still a successful result!
			} catch let error {
				removeItemResult = false
				MMLogError("An error occured while deleting persistent store files: \(error)")
			}
		}
		return removeItemResult;
	}
}