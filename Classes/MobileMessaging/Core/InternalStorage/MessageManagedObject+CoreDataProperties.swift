// 
//  MessageManagedObject+CoreDataProperties.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import CoreData

public extension MessageManagedObject {
    @NSManaged var creationDate: Date
    @NSManaged var messageId: String
    @NSManaged var reportSent: Bool
    @NSManaged var seenDate: Date?
	@NSManaged var payload: DictionaryRepresentation?
	@NSManaged var messageTypeValue: Int16
    @NSManaged var seenStatusValue: Int16
    @NSManaged var isSilent: Bool
	@NSManaged var campaignStateValue: Int16
	@NSManaged var campaignId: String?
	@NSManaged var deliveryReportedDate: Date?
	@NSManaged var deliveryMethod: Int16
}
