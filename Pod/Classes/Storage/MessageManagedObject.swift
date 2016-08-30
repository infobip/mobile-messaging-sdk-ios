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

final class MessageManagedObject: NSManagedObject, Fetchable {
	override func MM_awakeFromCreation() {
		self.creationDate = NSDate()
	}
    var seenStatus: MMSeenStatus {
		get { return MMSeenStatus(rawValue: Int32(seenStatusValue.intValue)) ?? .NotSeen }
		set { seenStatusValue = NSNumber(value: newValue.rawValue) }
    }
}
