//
//  UserSessionsReportingOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 17.01.2020.
//

import Foundation
import CoreData

class UserSessionsReportingOperation : MMOperation {
	
	let context: NSManagedObjectContext
	let mmContext: MobileMessaging
	var finishedSessionReports: [UserSessionReportObject]?
	var startedSessionReports: [UserSessionReportObject]?

	let finishBlock: (Error?) -> Void

    init(userInitiated: Bool, mmContext: MobileMessaging, context: NSManagedObjectContext, finishBlock: @escaping (Error?) -> Void) {
		self.mmContext = mmContext
		self.context = context
		self.finishBlock = finishBlock
		super.init(isUserInitiated: userInitiated)
		self.addCondition(HealthyRegistrationCondition(mmContext: mmContext))
		self.addCondition(NotPendingDepersonalizationCondition(mmContext: mmContext))
	}

	override func execute() {
		guard !isCancelled else {
			logDebug("cancelled...")
			finish()
			return
		}
		guard let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			logWarn("There is no registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		context.performAndWait {
			let sessionEndTimestamp: NSDate = MobileMessaging.date.now.addingTimeInterval(-Consts.UserSessions.sessionTimeoutSec) as NSDate

			self.startedSessionReports = UserSessionReportObject.MM_findAllWithPredicate(
				NSPredicate(format: "startReported == false"),
				context: self.context)
			self.finishedSessionReports = UserSessionReportObject.MM_findAllWithPredicate(
				NSPredicate(format: "endDate <= %@", sessionEndTimestamp),
				context: self.context)

			logSessionReports()

			let body = UserSessionMapper.requestPayload(newSessions: self.startedSessionReports, finishedSessions: self.finishedSessionReports)
			if !(self.startedSessionReports?.isEmpty ?? true) || !(self.finishedSessionReports?.isEmpty ?? true) {
				self.mmContext.remoteApiProvider.sendUserSessionReport(
					applicationCode: self.mmContext.applicationCode,
					pushRegistrationId: pushRegistrationId,
					body: body,
                    queue: underlyingQueue,
					completion: { result in
						self.handleResult(result)
						self.finishWithError(result.error)
				})
			} else {
				self.finish()
			}
		}
	}

	fileprivate func logSessionReports() {
		if let finishedSessionReports = finishedSessionReports?.map({ "\($0.pushRegistrationId) \($0.startDate) \($0.endDate)" }) {
			logDebug("finished session reports found: \(finishedSessionReports)")
		} else {
			logDebug("no finished session reports found")
		}
		if let newSessionReports = self.startedSessionReports?.map({ "\($0.pushRegistrationId) \($0.startDate) \($0.endDate)" }) {
			logDebug("new session reports found: \(newSessionReports)")
		} else {
			logDebug("no new session reports found")
		}
	}

	private func handleResult(_ result: UserSessionSendingResult) {
		switch result {
		case .Success(_):
			logDebug("Request succeeded")
			if !(self.startedSessionReports?.isEmpty ?? true) || !(self.finishedSessionReports?.isEmpty ?? true) {
				context.performAndWait {
					self.startedSessionReports?.forEach { (obj) in
						logDebug("marking start reported: \(obj)")
						obj.startReported = true
					}
					self.finishedSessionReports?.forEach { (obj) in
						logDebug("removing: \(obj)")
						self.context.delete(obj)
					}
				}
				context.MM_saveToPersistentStoreAndWait()
			}
		case .Failure(let error):
			logError("Request failed with error: \(error.orNil)")
		case .Cancel:
			break
		}
	}

	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished: \(errors)")
		finishBlock(errors.first)
	}
}
