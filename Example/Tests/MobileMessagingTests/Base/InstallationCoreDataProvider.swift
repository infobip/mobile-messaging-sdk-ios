//
//
//  Created by Andrey K. on 18/04/16.
//
//

import Foundation
import CoreData
@testable import MobileMessaging

protocol InstallationDataProvider {
}

class CoreDataProvider: InstallationDataProvider {
	let coreDataStorage: MMCoreDataStorage
	let context: NSManagedObjectContext

	required init(storage: MMCoreDataStorage) {
		self.coreDataStorage = storage
		self.context = storage.newPrivateContext()
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
