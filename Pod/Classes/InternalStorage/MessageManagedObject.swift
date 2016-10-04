//
//  MessageManagedObject.swift
//  
//
//  Created by Andrey K. on 24/02/16.
//
//

import Foundation
import CoreData

@objc public enum MMSeenStatus: Int16 {
    case NotSeen = 0
    case SeenNotSent
    case SeenSent
}

enum MMMessageType : Int16 {
	case Default = 0
	case Geo
}

final class MessageManagedObject: NSManagedObject, Fetchable {
	override func MM_awakeFromCreation() {
		self.creationDate = Date()
	}
    var seenStatus: MMSeenStatus {
		get { return MMSeenStatus(rawValue: seenStatusValue) ?? .NotSeen }
		set { seenStatusValue = newValue.rawValue }
    }
	var messageType: MMMessageType {
		get { return MMMessageType(rawValue: messageTypeValue) ?? .Default }
		set { messageTypeValue = newValue.rawValue }
	}
}