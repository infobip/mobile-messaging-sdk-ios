//
//  MessageManagedObject+CoreDataProperties.swift
//
//  Created by okoroleva on 16.05.16.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
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
