//
//  CustomEventReportingOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 31.01.2020.
//

import Foundation
import CoreData

class CustomEventReportingOperation: MMOperation {
	
	let mmContext: MobileMessaging
	var eventManagedObjects: [CustomEventObject]?
	let finishBlock: ((NSError?) -> Void)
	let context: NSManagedObjectContext
	let customEvent: MMCustomEvent?

    init(userInitiated: Bool, customEvent: MMCustomEvent?, context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: @escaping ((NSError?) -> Void)) {
		self.customEvent = customEvent
		self.context = context
		self.mmContext = mmContext
		self.finishBlock = finishBlock
        super.init(isUserInitiated: userInitiated)
		self.addCondition(HealthyRegistrationCondition(mmContext: mmContext))
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
		logDebug("Started...")

		performRequest(pushRegistrationId: pushRegistrationId)
	}

	private func performRequest(pushRegistrationId: String) {
		let body: RequestBody?
		if isEventProvidedByUser, let customEvent = customEvent {
			body = CustomEventMapper.requestBody(event: customEvent)
		} else {
			var body_local: RequestBody? = nil
			context.performAndWait {
				self.eventManagedObjects = CustomEventObject.MM_findAllInContext(self.context)
				body_local = CustomEventMapper.requestBody(events: self.eventManagedObjects)
			}
			body = body_local
		}

		if let body = body {
			logDebug("sending request...")
			let validate = isEventProvidedByUser
            mmContext.remoteApiProvider.sendCustomEvent(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId, validate: validate, body: body, queue: self.underlyingQueue, completion:
				{ result in
					self.handleResult(result)
					self.finishWithError(result.error)
			})
		} else {
			logDebug("nothing to send, finishing...")
			self.finish()
		}
	}

	private var isEventProvidedByUser: Bool {
		return customEvent != nil
	}

	private func handleResult(_ result: CustomEventResult) {
        assert(!Thread.isMainThread)
		switch result {
		case .Success( _):
			logDebug("successfully synced")
			if isEventProvidedByUser {
				// do nothing, just pass the result
			} else {
				// report retry finished, remove reported events from persistant storage
				context.performAndWait {
					if let eventManagedObjects = self.eventManagedObjects, !eventManagedObjects.isEmpty {
						logDebug("deleting \(eventManagedObjects.count) reported events")
						eventManagedObjects.forEach {
							self.context.delete($0)
						}
						self.context.MM_saveToPersistentStoreAndWait()
					}
				}
			}
		case .Failure(let error):
			if isEventProvidedByUser {
				// do nothing, just pass the error by to the user
			} else {
				// do nothing. in this case all business errors are silenced on the server, only 5xx may be returned here, we keep the state until next request attempt
			}
			logError("request failed with error: \(error.orNil)")
			return
		case .Cancel:
			logWarn("request cancelled.")
			return
		}
	}

	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		finishBlock(errors.first)
	}
}
