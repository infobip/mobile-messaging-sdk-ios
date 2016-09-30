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

extension MessageManagedObject {
    @NSManaged var creationDate: NSDate
    @NSManaged var messageId: String
    @NSManaged var reportSent: Bool
    @NSManaged var seenDate: NSDate?
	@NSManaged var payload: [String: AnyObject]?
	@NSManaged var messageTypeValue: NSNumber
    @NSManaged var seenStatusValue: Int16
    @NSManaged var isSilent: Bool
}