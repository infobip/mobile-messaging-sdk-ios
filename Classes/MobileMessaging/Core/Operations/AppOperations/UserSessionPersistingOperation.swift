//
//  UserSessionPersistingOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 17.01.2020.
//

import Foundation
import CoreData

class UserSessionPersistingOperation : MMOperation {
	
	let context: NSManagedObjectContext
	let mmContext: MobileMessaging
	let finishBlock: (Error?) -> Void
	let pushRegId: String
	let sessionTimestamp: Date

    init(userInitiated: Bool, mmContext: MobileMessaging, pushRegId: String, sessionTimestamp: Date, context: NSManagedObjectContext, finishBlock: @escaping ((Error?) -> Void)) {
		self.pushRegId = pushRegId
		self.sessionTimestamp = sessionTimestamp
		self.finishBlock = finishBlock
		self.mmContext = mmContext
		self.context = context
		super.init(isUserInitiated: userInitiated)
	}

	override func execute() {
		logVerbose("started...")
		context.performAndWait {

			if let currentSessions = UserSessionReportObject.MM_findAllWithPredicate(NSPredicate(format: "endDate > %@", MobileMessaging.date.now.addingTimeInterval(-Consts.UserSessions.sessionTimeoutSec) as NSDate), context: context), !currentSessions.isEmpty {
				self.logVerbose("\(currentSessions.count) current sessions found, updating endDate \(self.sessionTimestamp)")
				currentSessions.forEach { currentSession in
					currentSession.endDate = self.sessionTimestamp
					currentSession.pushRegistrationId = self.pushRegId
				}
			} else {
				self.logVerbose("saving new session \(self.sessionTimestamp)")
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
        assert(userInitiated == Thread.isMainThread)
		logVerbose("finished: \(errors)")
		finishBlock(errors.first)
	}
}
