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
    @NSManaged var email: String?
    @NSManaged var internalId: String?
    @NSManaged var metaData: NSObject?
    @NSManaged var msisdn: String?
    @NSManaged var osVersion: String?
    @NSManaged var deviceModel: String?
    @NSManaged var libraryVersion: String?
    @NSManaged var hostingAppVersion: String?
    @NSManaged var mobileCarrierName: String?
    @NSManaged var mobileCountryCode: String?
    @NSManaged var mobileNetworkCode: String?

}
