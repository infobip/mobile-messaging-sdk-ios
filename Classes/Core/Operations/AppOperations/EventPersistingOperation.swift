//
//  EventPersistingOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 19.08.2020.
//

import Foundation
import CoreData

class EventPersistingOperation : MMOperation {
	let context: NSManagedObjectContext
	let finishBlock: (Error?) -> Void
	let pushRegId: String
	let customEvent: CustomEvent

	init(customEvent: CustomEvent, mmContext: MobileMessaging, pushRegId: String, context: NSManagedObjectContext, finishBlock: @escaping ((Error?) -> Void)) {
		self.pushRegId = pushRegId
		self.customEvent = customEvent
		self.finishBlock = finishBlock
		self.context = context
		super.init()
	}

	override func execute() {
		guard !isCancelled else {
			logDebug("cancelled...")
			finish()
			return
		}
		logVerbose("started...")
		self.context.performAndWait {
			let new = CustomEventObject.MM_createEntityInContext(context: self.context)
			new.eventDate = MobileMessaging.date.now
			new.definitionId = customEvent.definitionId
			new.payload = customEvent.properties
			new.pushRegistrationId = self.pushRegId
			self.context.MM_saveToPersistentStoreAndWait()
		}
		finish()
	}

	override func finished(_ errors: [NSError]) {
		logVerbose("finished: \(errors)")
		finishBlock(errors.first)
	}
}
