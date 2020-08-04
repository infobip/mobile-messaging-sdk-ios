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

			if let currentSessions = UserSessionReportObject.MM_findAllWithPredicate(NSPredicate(format: "endDate > %@", MobileMessaging.date.now.addingTimeInterval(-Consts.UserSessions.sessionTimeoutSec) as NSDate), context: context), !currentSessions.isEmpty {
				MMLogVerbose("[UserSessionPersisting] \(currentSessions.count) current sessions found, updating endDate \(self.sessionTimestamp)")
				currentSessions.forEach { currentSession in
					currentSession.endDate = self.sessionTimestamp
					currentSession.pushRegistrationId = self.pushRegId
				}
			} else {
				MMLogVerbose("[UserSessionPersisting] saving new session \(self.sessionTimestamp)")
				let newSession = UserSessionReportObject.MM_createEntityInContext(context: self.context)
				newSession.startDate = self.sessionTimestamp
				newSession.endDate = self.sessionTimestamp.addingTimeInterval(Consts.UserSessions.sessionSaveInterval) // minimum session len
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
