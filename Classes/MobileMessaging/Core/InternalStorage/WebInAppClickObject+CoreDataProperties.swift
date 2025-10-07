// 
//  WebInAppClickObject+CoreDataProperties.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import CoreData

extension WebInAppClickObject {
    @NSManaged public var clickUrl: String
    @NSManaged public var pushRegistrationId: String
    @NSManaged public var buttonIdx: String
    @NSManaged public var attempt: Int16
}
