//
//  CustomEventObject+CoreDataProperties.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 31.01.2020.
//
//

import Foundation
import CoreData

extension CustomEventObject {
    @NSManaged public var eventDate: Date
	@NSManaged public var payload: [String: Any]?
    @NSManaged public var pushRegistrationId: String
	@NSManaged public var definitionId: String
}
