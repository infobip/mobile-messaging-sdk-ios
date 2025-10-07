// 
//  UserSessionReportObject+CoreDataProperties.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import CoreData

extension UserSessionReportObject {
    @NSManaged public var pushRegistrationId: String
    @NSManaged public var startDate: Date
    @NSManaged public var endDate: Date
	@NSManaged public var startReported: Bool
}
