//
//  MessageManagedObject.swift
//  
//
//  Created by Andrey K. on 24/02/16.
//
//

import Foundation
import CoreData

enum MMSeenStatus : Int32 {
    case NotSeen = 0
    case SeenNotSent
    case SeenSent
}

class MessageManagedObject: NSManagedObject {

    var seenStatus: MMSeenStatus {
		get { return MMSeenStatus(rawValue: seenStatusValue.intValue) ?? .NotSeen }
		set { seenStatusValue = NSNumber(int: newValue.rawValue) }
    }
}
