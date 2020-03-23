//
//  UserSessionReportObject+CoreDataProperties.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 20.01.2020.
//
//

import Foundation
import CoreData

extension UserSessionReportObject {
    @NSManaged public var pushRegistrationId: String
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date
	@NSManaged public var startReported: Bool
}
