//
//  CustomEventReportingOperation.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 31.01.2020.
//

import Foundation
import CoreData

class CustomEventReportingOperation: Operation {
	let mmContext: MobileMessaging
	var eventManagedObjects: [CustomEventObject]?
	let finishBlock: ((NSError?) -> Void)
	let context: NSManagedObjectContext
	let customEvent: CustomEvent?

	init(customEvent: CustomEvent?, context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: @escaping ((NSError?) -> Void)) {
		self.customEvent = customEvent
		self.context = context
		self.mmContext = mmContext
		self.finishBlock = finishBlock
	}

	override func execute() {
		guard !isCancelled else {
			MMLogDebug("[CustomEventReportingOperation] cancelled...")
			finish()
			return
		}
		guard let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			MMLogWarn("[CustomEventReportingOperation] There is no registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogWarn("[CustomEventReportingOperation] Registration is not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.InvalidRegistration))
			return
		}
		MMLogDebug("[CustomEventReportingOperation] Started...")

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
			MMLogDebug("[CustomEventReportingOperation] sending request...")
			let validate = isEventProvidedByUser
			mmContext.remoteApiProvider.sendCustomEvent(applicationCode: mmContext.applicationCode, pushRegistrationId: pushRegistrationId, validate: validate, body: body, completion:
				{ result in
					self.handleResult(result)
					self.finishWithError(result.error)
			})
		} else {
			MMLogDebug("[CustomEventReportingOperation] nothing to send, finishing...")
			self.finish()
		}
	}

	private var isEventProvidedByUser: Bool {
		return customEvent != nil
	}

	private func handleResult(_ result: CustomEventResult) {
		switch result {
		case .Success( _):
			MMLogDebug("[CustomEventReportingOperation] successfully synced")
			if isEventProvidedByUser {
				// do nothing, just pass the result
			} else {
				// report retry finished, remove reported events from persistant storage
				context.performAndWait {
					if let eventManagedObjects = self.eventManagedObjects, !eventManagedObjects.isEmpty {
						MMLogDebug("[CustomEventReportingOperation] deleting \(eventManagedObjects.count) reported events")
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
			MMLogError("[CustomEventReportingOperation] request failed with error: \(error.orNil)")
			return
		case .Cancel:
			MMLogWarn("[CustomEventReportingOperation] request cancelled.")
			return
		}
	}

	override func finished(_ errors: [NSError]) {
		MMLogDebug("[CustomEventReportingOperation] finished with errors: \(errors)")
		finishBlock(errors.first)
	}
}
