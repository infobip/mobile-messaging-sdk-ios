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

extension GeoEventReportObject {

    @NSManaged var geoAreaId: String
    @NSManaged var eventDate: NSDate
    @NSManaged var eventType: String
    @NSManaged var campaignId: String

}
