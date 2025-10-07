// 
//  Message+CoreDataProperties.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import CoreData

public extension Message {

    @NSManaged var messageId: String
	@NSManaged var payload: DictionaryRepresentation
    @NSManaged var isDeliveryReportSent: Bool
    @NSManaged var seenStatusValue: Int16
    @NSManaged var createdDate: Date
	@NSManaged var deliveryMethod: Int16
	@NSManaged var direction: Int16
	@NSManaged var sentStatusValue: Int16
	@NSManaged var deliveryReportedDate: Date?
	@NSManaged var seenDate: Date?
}
