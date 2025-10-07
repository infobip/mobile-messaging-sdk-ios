// 
//  CustomEventObject+CoreDataProperties.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import CoreData

extension CustomEventObject {
    @NSManaged public var eventDate: Date
	@NSManaged public var payload: [String: Any]?
    @NSManaged public var pushRegistrationId: String
	@NSManaged public var definitionId: String
}
