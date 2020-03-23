//
//  UserSessionPersistingOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 17.01.2020.
//

import Foundation
import CoreData

class UserSessionPersistingOperation : Operation {
	let context: NSManagedObjectContext
	let mmContext: MobileMessaging
	let finishBlock: (Error?) -> Void
	let pushRegId: String
	let sessionTimestamp: Date

	init(mmContext: MobileMessaging, pushRegId: String, sessionTimestamp: Date, context: NSManagedObjectContext, finishBlock: @escaping ((Error?) -> Void)) {
		self.pushRegId = pushRegId
		self.sessionTimestamp = sessionTimestamp
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		self.context = context
	}

	override func execute() {
		MMLogVerbose("[UserSessionPersisting] started...")
		context.performAndWait {
			if let currentSession = mmContext.userSessionService.fetchCurrentSession(pushRegistrationId: self.pushRegId) {
				MMLogVerbose("[UserSessionPersisting] current session found, updating endDate \(self.sessionTimestamp)")
				currentSession.endDate = self.sessionTimestamp
			} else {
				MMLogVerbose("[UserSessionPersisting] saving new session \(self.sessionTimestamp)")
				let newSession = UserSessionReportObject.MM_createEntityInContext(context: self.context)
				newSession.startDate = self.sessionTimestamp
				newSession.endDate = self.sessionTimestamp
				newSession.pushRegistrationId = self.pushRegId
			}
			self.context.MM_saveToPersistentStoreAndWait()
		}
		finish()
	}

	override func finished(_ errors: [NSError]) {
		MMLogVerbose("[UserSessionPersisting] finished: \(errors)")
		finishBlock(errors.first)
	}
}
