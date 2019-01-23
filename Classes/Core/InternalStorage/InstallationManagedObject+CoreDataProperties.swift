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
    @NSManaged var pushServiceToken: String?
    @NSManaged var pushRegId: String?
	@NSManaged var externalUserId: String?
    @NSManaged var customUserAttributes: DictionaryRepresentation?
	@NSManaged var systemDataHash: Int64
	@NSManaged var location: AnyObject?
	@NSManaged var regEnabled: Bool
	@NSManaged var applicationCode: String?
	@NSManaged var isPrimary: Bool
	@NSManaged var logoutStatusValue: Int16
	@NSManaged var logoutFailCounter: Int16
	@NSManaged var dirtyAttributesString: String?

	@NSManaged var phones: [Phone]?
	@NSManaged var firstName: String?
	@NSManaged var lastName: String?
	@NSManaged var middleName: String?
	@NSManaged var gender: String?
	@NSManaged var birthday: String?
	@NSManaged var emails: [Email]?
	@NSManaged var tags: [String]?
	@NSManaged var instances: [Installation]?
	@NSManaged var customInstanceAttributes: DictionaryRepresentation?
}
