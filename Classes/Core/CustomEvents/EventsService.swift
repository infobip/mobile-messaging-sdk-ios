//
//  EventsService.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 31.01.2020.
//

import Foundation
import CoreData

@objcMembers public class MMBaseEvent: NSObject {
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
@objcMembers public class MMCustomEvent: MMBaseEvent {
	/**
	Arbitrary contextual data of the custom event.
	*/
	public let properties: [String: MMEventPropertyType]?

	/**
	Initializes a custom event.
	- parameter definitionId: Event ID that is generated on the Portal for your custom Event Definition.
	- parameter properties: Arbitrary contextual data of the custom event.
	*/
	public init(definitionId: String, properties: [String: MMEventPropertyType]?) {
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
    private let q: DispatchQueue
    private let eventReportingQueue: MMOperationQueue
    private let eventPersistingQueue: MMOperationQueue
	private let context: NSManagedObjectContext
	lazy var reportPostponer = MMPostponer(executionQueue: DispatchQueue.global())

	init(mmContext: MobileMessaging) {
        self.q = DispatchQueue(label: "events-service", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
		self.context = mmContext.internalStorage.newPrivateContext()
        self.eventReportingQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q)
        self.eventPersistingQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q)
		super.init(mmContext: mmContext, uniqueIdentifier: "EventsService")
	}

	func submitEvent(customEvent: MMCustomEvent, reportImmediately: Bool, completion: @escaping (NSError?) -> Void) {
		guard let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			completion(NSError(type: .NoRegistration))
			return
		}
		if reportImmediately {
            self.scheduleReport(userInitiated: true, customEvent: customEvent, completion: completion)
		} else {
			persistEvent(customEvent, pushRegistrationId) {
                self.reportPostponer.postponeBlock(block: {
                    self.scheduleReport(userInitiated: false, customEvent: nil, completion: completion)
                })
			}
		}
	}

    override func appWillEnterForeground(_ completion: @escaping () -> Void) {
        scheduleReport(userInitiated: false, customEvent: nil, completion: { _ in completion() })
	}

	private func persistEvent(_ customEvent: MMCustomEvent, _ pushRegistrationId: String, completion: @escaping () -> Void) {
		eventPersistingQueue.addOperation(EventPersistingOperation(customEvent: customEvent, mmContext: mmContext, pushRegId: pushRegistrationId, context: context, finishBlock: { _ in completion() }))
	}

    private func scheduleReport(userInitiated: Bool, customEvent: MMCustomEvent?, completion: @escaping ((NSError?) -> Void)) {
        self.eventReportingQueue.addOperation(CustomEventReportingOperation(userInitiated: userInitiated, customEvent: customEvent, context: context, mmContext: self.mmContext, finishBlock: completion))
	}
}
