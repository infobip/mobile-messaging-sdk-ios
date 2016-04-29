//
//  MessageManagedObject+CoreDataProperties.swift
//  Pods
//
//  Created by okoroleva on 20.04.16.
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
    @NSManaged var reportSent: NSNumber
    @NSManaged var seenDate: NSDate?
    @NSManaged var seenStatusValue: NSNumber
    @NSManaged var supplementaryId: String

}
