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

    @NSManaged var badgeNumber: Int
    @NSManaged var deviceToken: String?
    @NSManaged var dirtyAttributes: Int32
    @NSManaged var internalUserId: String?
	@NSManaged var externalUserId: String?
    @NSManaged var customUserData: DictionaryRepresentation?
	@NSManaged var predefinedUserData: DictionaryRepresentation?
	@NSManaged var systemDataHash: Int64
	@NSManaged var location: AnyObject?
	@NSManaged var isRegistrationEnabled: Bool
	@NSManaged var applicationCode: String?
}
