//
//  MMCoreDataExtensions.swift
//
//  Created by Andrey K. on 18/05/16.
//
//

import CoreData

extension String {
	/// Skips initial space characters (whitespaceSet). Returns true if the firsh character is one of "Y", "y", "T", "t".
	var boolValue: Bool {
		let trimmedString = self.trimmingCharacters(in: .whitespaces)
		guard let firstChar = trimmedString.characters.first else {
			return false
		}
		return ["t", "T", "y", "Y"].contains(firstChar)
	}
}

struct MMContextSaveOptions: OptionSet {
	let rawValue : Int
	init(rawValue: Int) { self.rawValue = rawValue }
	static let SaveSynchronously	= MMContextSaveOptions(rawValue: 1 << 0)
	static let SaveParent		= MMContextSaveOptions(rawValue: 1 << 1)
}

protocol Fetchable: NSFetchRequestResult {
	static func MM_requestAll(_ predicate: NSPredicate?) -> NSFetchRequest<Self>
	static func MM_executeRequest(_ request: NSFetchRequest<Self>, inContext ctx: NSManagedObjectContext) -> [Self]?
	static func MM_deleteAllMatchingPredicate(_ predicate: NSPredicate?, inContext context: NSManagedObjectContext)
	static func MM_executeFetchRequestAndReturnFirstObject(_ request: NSFetchRequest<Self>, inContext context: NSManagedObjectContext) -> Self?
	static func MM_findFirstInContext(_ context: NSManagedObjectContext) -> Self?
	static func MM_findFirstWithPredicate(_ predicate: NSPredicate?, context: NSManagedObjectContext) -> Self?
	static func MM_findAllWithPredicate(_ predicate: NSPredicate?, context: NSManagedObjectContext) -> [Self]?
	static func MM_findAllInContext(_ context: NSManagedObjectContext) -> [Self]?
	static func MM_countOfEntitiesWithContext(_ context: NSManagedObjectContext) -> Int
	static func MM_countOfEntitiesWithPredicate(_ predicate: NSPredicate?, inContext context: NSManagedObjectContext) -> Int
	static func MM_selectAttribute(_ attribute: String, withPredicte predicate: NSPredicate?, inContext context: NSManagedObjectContext) -> [String: AnyObject]?
	static func MM_find(withPredicate predicate: NSPredicate, fetchLimit: Int, sortedBy: String, ascending: Bool, inContext context: NSManagedObjectContext) -> [Self]?
	static func MM_findAll(withPredicate predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, limit: Int?, skip: Int?, inContext context: NSManagedObjectContext) -> [Self]?
}

protocol Updatable: NSFetchRequestResult {
	static func MM_batchUpdate(propertiesToUpdate: [AnyHashable: Any], predicate: NSPredicate?, inContext ctx: NSManagedObjectContext) -> NSBatchUpdateResult?
}

extension Updatable where Self: NSManagedObject {
	@discardableResult
	static func MM_batchUpdate(propertiesToUpdate: [AnyHashable: Any], predicate: NSPredicate?, inContext ctx: NSManagedObjectContext) -> NSBatchUpdateResult? {
		let request = self.MM_batchUpdateRequest(predicate, propertiesToUpdate: propertiesToUpdate)
		let result: NSPersistentStoreResult?
		
		do {
			result = try ctx.execute(request)
		}
		catch let error as NSError {
			result = nil
			MMLogError("[Core Data] batch update error: \(error)")
		}
		return result as? NSBatchUpdateResult
	}
	
	static func MM_batchUpdateRequest(_ predicate: NSPredicate?, propertiesToUpdate: [AnyHashable: Any]) -> NSBatchUpdateRequest {
		let r =  NSBatchUpdateRequest(entityName: self.MM_entityName)
		r.predicate = predicate
		r.propertiesToUpdate = propertiesToUpdate
		r.resultType = .statusOnlyResultType
		return r
	}
}

extension Fetchable where Self: NSManagedObject {
	static func MM_requestAll(_ predicate: NSPredicate?) -> NSFetchRequest<Self> {
		let r = NSFetchRequest<Self>(entityName: self.MM_entityName)
		r.predicate = predicate
		return r
	}
	
	static func MM_executeRequest(_ request: NSFetchRequest<Self>, inContext ctx: NSManagedObjectContext) -> [Self]? {
		var results: [Self]?
		let requestBlock = {
			do {
				results = try ctx.fetch(request)
			}
			catch let error as NSError {
				results = nil
				MMLogError("[Core Data] Fetching error: \(error)")
			}
		}
		if ctx.concurrencyType == NSManagedObjectContextConcurrencyType.confinementConcurrencyType {
			requestBlock()
		} else {
			ctx.performAndWait(requestBlock)
		}
		return results
	}
	

	static func MM_findAllWithPredicate(_ predicate: NSPredicate?, context: NSManagedObjectContext) -> [Self]? {
		let r: NSFetchRequest<Self> = self.MM_requestAll(predicate)
		return self.MM_executeRequest(r, inContext: context)
	}
	
	static func MM_deleteAllMatchingPredicate(_ predicate: NSPredicate?, inContext context: NSManagedObjectContext) {
		let request : NSFetchRequest<Self> = self.MM_requestAll(predicate)
		request.returnsObjectsAsFaults = true
		request.includesPropertyValues = false
		
		if let objectsToTruncate = MM_executeRequest(request, inContext: context) {
			for obj in objectsToTruncate {
				obj.MM_deleteEntityInContext(context)
			}
		}
	}
	
	static func MM_executeFetchRequestAndReturnFirstObject(_ request: NSFetchRequest<Self>, inContext context: NSManagedObjectContext) -> Self? {
		request.fetchLimit = 1
		let results = MM_executeRequest(request, inContext: context)
		return results?.first
	}
	
	static func MM_findFirstInContext(_ context: NSManagedObjectContext) -> Self? {
		return MM_findFirstWithPredicate(nil, context: context)
	}
	
	static func MM_findFirstWithPredicate(_ predicate: NSPredicate?, context: NSManagedObjectContext) -> Self? {
		let request : NSFetchRequest<Self> = MM_requestAll(predicate)
		return MM_executeFetchRequestAndReturnFirstObject(request, inContext: context)
	}
	
	static func MM_findAllInContext(_ context: NSManagedObjectContext) -> [Self]? {
		return MM_findAllWithPredicate(nil, context: context)
	}
	
	static func MM_countOfEntitiesWithContext(_ context: NSManagedObjectContext) -> Int {
		return MM_countOfEntitiesWithPredicate(nil, inContext: context)
	}
	
	static func MM_countOfEntitiesWithPredicate(_ predicate: NSPredicate?, inContext context: NSManagedObjectContext) -> Int {
		var count = 0
		do {
			count = try context.count(for: MM_requestAll(predicate))
		} catch let error as NSError {
			MMLogError(error.description)
		}
		return count
	}
	
	static func MM_selectAttribute(_ attribute: String, withPredicte predicate: NSPredicate?, inContext context: NSManagedObjectContext) -> [String: AnyObject]? {
		let request : NSFetchRequest<Self> = self.MM_requestAll(predicate)
		request.resultType = .dictionaryResultType
		request.propertiesToFetch = [attribute]
		
		if let results = MM_executeRequest(request, inContext: context) {
			let foundationArray = NSArray(array: results)
			return foundationArray.value(forKeyPath: NSString(format: "@unionOfObjects.%@", attribute) as String) as? [String: AnyObject]
		} else {
			return nil
		}
	}

	static func MM_requestAll(withPredicate predicate: NSPredicate? = nil, fetchLimit: Int, sortedBy sortTerm: String, ascending: Bool) -> NSFetchRequest<Self> {
		let r = self.MM_requestAll(predicate)
		
		var ascending = ascending
		var sortDescriptors = [NSSortDescriptor]()
		let sortKeys = sortTerm.components(separatedBy: ",")
		sortKeys.forEach { sortKey in
			var sortKey = sortKey
			let sortComps = sortKey.components(separatedBy: ":")
			if sortComps.count > 1 {
				if let customAscending = sortComps.last {
					ascending = customAscending.boolValue
					sortKey = sortComps[0]
				}
			}
			sortDescriptors.append(NSSortDescriptor(key: sortKey, ascending: ascending))
		}
		r.sortDescriptors = sortDescriptors
		r.fetchLimit = fetchLimit
		return r
	}
	
	static func MM_find(withPredicate predicate: NSPredicate, fetchLimit: Int, sortedBy: String, ascending: Bool, inContext context: NSManagedObjectContext) -> [Self]? {
		let r = self.MM_requestAll(withPredicate: predicate, fetchLimit: fetchLimit, sortedBy: sortedBy, ascending: ascending)
		return self.MM_executeRequest(r, inContext: context)
	}
	
	static func MM_findAll(withPredicate predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, limit: Int?, skip: Int?, inContext context: NSManagedObjectContext) -> [Self]? {
		let r = self.MM_requestAll(predicate)
		r.sortDescriptors = sortDescriptors
		r.fetchLimit = limit ?? 0
		r.fetchOffset = skip ?? 0
		return self.MM_executeRequest(r, inContext: context)
	}
	
}


extension NSManagedObject {
	class var MM_entityName: String {
		return NSStringFromClass(self).components(separatedBy: ".").last!
	}
	
	class func MM_entityDescription(inContext context: NSManagedObjectContext) -> NSEntityDescription {
		return NSEntityDescription.entity(forEntityName: self.MM_entityName, in: context)!
	}
	
	class func MM_createEntityInContext(_ entityDescription: NSEntityDescription? = nil, context: NSManagedObjectContext) -> Self {
		let entity = entityDescription ?? self.MM_entityDescription(inContext: context)
		let managedObject = self.init(entity: entity, insertInto: context)
		
		managedObject.MM_awakeFromCreation()
		return managedObject
	}
	
	func MM_awakeFromCreation() {}
	
	var MM_isEntityDeleted: Bool {
		return isDeleted || managedObjectContext == nil
	}

	@discardableResult
	func MM_deleteEntityInContext(_ context: NSManagedObjectContext) -> Bool {
		do {
			let objectInContext = try context.existingObject(with: objectID)
			context.delete(objectInContext)
			return objectInContext.MM_isEntityDeleted
		} catch let error as NSError {
			MMLogError("An error occured while deleting an object \(self): \(error)")
		}
		return false
	}
}

let kMMNSManagedObjectContextWorkingName = "kNSManagedObjectContextWorkingName"

extension NSManagedObjectContext {
	
	func MM_saveWithOptions(_ options: MMContextSaveOptions, completion: ((Bool, NSError?) -> Void)?) {
		let saveParentContexts = options.contains(.SaveParent)
		let saveSynchronously = options.contains(.SaveSynchronously)
		var ctxHasChanges: Bool = false
		if concurrencyType == NSManagedObjectContextConcurrencyType.confinementConcurrencyType {
			ctxHasChanges = hasChanges
		} else {
			performAndWait{ ctxHasChanges = self.hasChanges }
		}
		
		if hasChanges == false {
			MMLogDebug("NO CHANGES IN ** \(MM_workingName) ** CONTEXT - NOT SAVING")
			if (saveParentContexts && parent != nil) {
				MMLogVerbose("Proceeding to save parent context \(String(describing: parent?.MM_description))")
			} else {
				completion?(true, nil)
				return
			}
		}
		
		let saveBlock = {
			var optionsSummary = ""
			optionsSummary = optionsSummary.appending(saveParentContexts ? "Save Parents" : "")
			optionsSummary = optionsSummary.appending(saveSynchronously ? "Sync Save" : "")
			let numberOfInsertedObjects = self.insertedObjects.count
			let numberOfUpdatedObjects = self.updatedObjects.count
			let numberOfDeletedObjects = self.deletedObjects.count
			
			MMLogVerbose("Objects - Inserted \(numberOfInsertedObjects), Updated \(numberOfUpdatedObjects), Deleted \(numberOfDeletedObjects)")
			
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
					if let parentCtx = self.parent , saveParentContexts {
						let parentContentSaveOptions: MMContextSaveOptions = [.SaveSynchronously, .SaveParent]
						parentCtx.MM_saveWithOptions(parentContentSaveOptions, completion:completion)
					} else {
						// If we are not the default context (And therefore need to save the root context, do the completion action if one was specified
						MMLogDebug("→ Finished saving: \(self.MM_description)")
						completion?(saved, error)
					}
				}
			}
		}
		
		if concurrencyType == NSManagedObjectContextConcurrencyType.confinementConcurrencyType {
			saveBlock()
		} else if saveSynchronously == true {
			performAndWait(saveBlock)
		} else {
			perform(saveBlock)
		}
	}
	
	var MM_workingName: String {
		return (userInfo.object(forKey: kMMNSManagedObjectContextWorkingName) as? String) ?? "UNNAMED"
	}
	
	var MM_description: String {
		let thread = Thread.isMainThread ? "*** MAIN THREAD ***" : "*** BACKGROUND THREAD ***";
		return "\(MM_workingName) on \(thread)"
	}
	
	func MM_saveToPersistentStoreAndWait() {
		MM_saveWithOptions([.SaveParent, .SaveSynchronously], completion: nil)
	}
	
	func MM_saveToPersistentStore() {
		MM_saveWithOptions([.SaveParent], completion: nil)
	}
	
	func MM_saveOnlySelfAndWait() {
		MM_saveWithOptions([.SaveSynchronously], completion: nil)
	}
}

extension NSPersistentStore {
	@discardableResult
	func MM_removePersistentStoreFiles() -> Bool {
		guard let url = self.url else {
			return false
		}
		return NSPersistentStore.MM_removePersistentStoreFilesAtURL(url)
	}
	
	@discardableResult
	class func MM_removePersistentStoreFilesAtURL(_ url: URL) -> Bool {
		guard url.isFileURL else {
			assertionFailure("URL must be a file URL")
			return false
		}
		
		let rawURL : String = url.absoluteString
		let shmSidecar : URL = URL(string: rawURL.appending("-shm"))!
		let walSidecar : URL = URL(string: rawURL.appending("-wal"))!
		
		var removeItemResult = true
		
		for fileURL in [url, shmSidecar, walSidecar] {
			do {
				try FileManager.default.removeItem(at: fileURL)
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
