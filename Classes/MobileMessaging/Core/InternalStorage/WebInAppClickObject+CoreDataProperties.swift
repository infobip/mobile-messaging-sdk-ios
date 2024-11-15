//
//  WebInAppClickObject+CoreDataProperties.swift
//  MobileMessaging
//
//  Created by Luka Ilic on 19.09.2024..
//

import Foundation
import CoreData

extension WebInAppClickObject {
    @NSManaged public var clickUrl: String
    @NSManaged public var pushRegistrationId: String
    @NSManaged public var buttonIdx: String
    @NSManaged public var attempt: Int16
}
