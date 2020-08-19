//
//  EventsService.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 31.01.2020.
//

import Foundation
import CoreData

@objcMembers public class BaseEvent: NSObject {
	/**
	Event ID that is generated on the Portal for your custom Event Definition.
	*/
	public let definitionId: String
	public init(definitionId: String) {
		self.definitionId = definitionId
	}
}

/**
CustomEvent class represents Custom event. Events allow you to track arbitrary user actions and collect arbitrary contextual information represented by event key-value properties.
*/
@objcMembers public class CustomEvent: BaseEvent {
	/**
	Arbitrary contextual data of the custom event.
	*/
	public let properties: [String: EventPropertyType]?

	/**
	Initializes a custom event.
	- parameter definitionId: Event ID that is generated on the Portal for your custom Event Definition.
	- parameter properties: Arbitrary contextual data of the custom event.
	*/
	public init(definitionId: String, properties: [String: EventPropertyType]?) {
		self.properties = properties
		super.init(definitionId: definitionId)
	}
	
	//Method is needed for plugins support
	public required convenience init?(dictRepresentation dict: DictionaryRepresentation) {
		let value = JSON.init(dict)
		guard let definitionId = value["definitionId"].string else {
			return nil
		}
		self.init(definitionId: definitionId,
				  properties: value["properties"].dictionary?.decodeCustomEventPropertiesJSON)
	}
}

class EventsService: MobileMessagingService {
	private let eventReportingQueue = MMOperationQueue.newSerialQueue
	private let eventPersistingQueue = MMOperationQueue.newSerialQueue
	private let context: NSManagedObjectContext
	lazy var reportPostponer = MMPostponer(executionQueue: DispatchQueue.global())

	override init(mmContext: MobileMessaging) {
		self.context = mmContext.internalStorage.newPrivateContext()
		super.init(mmContext: mmContext)
	}

	func submitEvent(customEvent: CustomEvent, reportImmediately: Bool, completion: @escaping (NSError?) -> Void) {
		guard let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			completion(NSError(type: .NoRegistration))
			return
		}
		if reportImmediately {
			eventReportingQueue.addOperation(CustomEventReportingOperation(customEvent: customEvent, context: context, mmContext: self.mmContext, finishBlock: completion))
		} else {
			persistEvent(customEvent, pushRegistrationId) {
				self.reportEvents(immediately: reportImmediately, completion: completion)
			}
		}
	}

	override func appWillEnterForeground(_ notification: Notification) {
		scheduleReport(completion: { _ in })
	}

	private func persistEvent(_ customEvent: CustomEvent, _ pushRegistrationId: String, completion: @escaping () -> Void) {
		eventPersistingQueue.addOperation {
			self.context.performAndWait {
				let new = CustomEventObject.MM_createEntityInContext(context: self.context)
				new.eventDate = MobileMessaging.date.now
				new.definitionId = customEvent.definitionId
				new.payload = customEvent.properties
				new.pushRegistrationId = pushRegistrationId
			}
			self.context.MM_saveToPersistentStoreAndWait()
			completion()
		}
	}

	private func reportEvents(immediately: Bool, completion: @escaping (NSError?) -> Void) {
		if immediately {
			self.scheduleReport(completion: completion)
		} else {
			reportPostponer.postponeBlock(block: {
				self.scheduleReport(completion: completion)
			})
		}
	}

	private func scheduleReport(completion: @escaping ((NSError?) -> Void)) {
		self.eventReportingQueue.addOperation(CustomEventReportingOperation(customEvent: nil, context: context, mmContext: self.mmContext, finishBlock: completion))
	}
}
