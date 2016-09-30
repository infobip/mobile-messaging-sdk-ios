//
//  InstallationManagedObject+CoreDataProperties.swift
//  
//
//  Created by Andrey K. on 24/02/16.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension InstallationManagedObject {

    @NSManaged var badgeNumber: NSNumber
    @NSManaged var deviceToken: String?
    @NSManaged var dirtyAttributes: NSNumber
    @NSManaged var internalUserId: String?
	@NSManaged var externallUserId: String?
	
    @NSManaged var customUserData: [String: AnyObject]?
	@NSManaged var predefinedUserData: [String: AnyObject]?
	
	@NSManaged var systemDataHash: NSNumber
	@NSManaged var location: AnyObject?
}