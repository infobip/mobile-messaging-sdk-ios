//
//  Message+CoreDataProperties.swift
//
//  Created by Andrey K. on 15/09/16.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
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
