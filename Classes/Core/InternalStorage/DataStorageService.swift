//
//  DataStorageService.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14/01/2019.
//

import Foundation

let installationQueue = MMOperationQueue.newSerialQueue

class DataStorageService: MobileMessagingService {
	let coreDataProvider: CoreDataProvider
	let inMemoryProvider: InMemoryDataProvider
	init(inMemoryProvider: InMemoryDataProvider, coreDataProvider: CoreDataProvider, mmContext: MobileMessaging) {
		self.inMemoryProvider = inMemoryProvider
		self.coreDataProvider = coreDataProvider
		super.init(mmContext: mmContext, id: "com.mobile-messaging.subservice.\(type(of: self))")
	}

	func persist() {
		coreDataProvider.persist()
		inMemoryProvider.persist()
	}

	func shouldSaveInMemory(forAttribute attr: Attributes) -> Bool {
		return false
	}

	func resolveProvider(forAttributes attributes: Attributes) -> InstallationDataProvider {
		if shouldSaveInMemory(forAttribute: attributes) {
			return inMemoryProvider
		}
		return coreDataProvider
	}

	func resetNeedToSync(attributesSet: AttributesSet) {
		attributesSet.forEach { (attribute) in
			resolveProvider(forAttributes: attribute).resetDirtyAttribute(attribute)
		}
	}
}
