//
//  GeoCleanupOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 19.08.2020.
//

import Foundation
import CoreData

class GeoCleanupOperation : MMOperation {
	let context: NSManagedObjectContext
	let finishBlock: (Error?) -> Void
	let datasource: GeofencingInMemoryDatasource

	init(datasource: GeofencingInMemoryDatasource, finishBlock: @escaping ((Error?) -> Void)) {
		self.datasource = datasource
		self.finishBlock = finishBlock
		self.context = datasource.context

		super.init(isUserInitiated: false)
	}

	override func execute() {
		logVerbose("started...")
		self.datasource.cleanup()
		context.performAndWait {
			MessageManagedObject.MM_deleteAllMatchingPredicate(NSPredicate(format: "messageTypeValue == \(MMMessageType.Geo.rawValue)"), inContext: context)
			GeoEventReportObject.MM_deleteAllMatchingPredicate(nil, inContext: context)
			context.MM_saveToPersistentStoreAndWait()
		}

		finish()
	}

	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logVerbose("finished: \(errors)")
		finishBlock(errors.first)
	}
}
