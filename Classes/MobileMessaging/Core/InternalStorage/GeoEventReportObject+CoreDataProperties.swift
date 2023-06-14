//
//  GeoEventReportObject+CoreDataProperties.swift
//  
//
//  Created by Andrey K. on 21/10/2016.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

public extension GeoEventReportObject {
    @NSManaged var geoAreaId: String
    @NSManaged var eventDate: Date
    @NSManaged var eventType: String
    @NSManaged var campaignId: String
	@NSManaged var messageId: String
	@NSManaged var sdkMessageId: String
	@NSManaged var messageShown: Bool
}
