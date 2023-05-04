//
//  MessageManagedObject.swift
//  
//
//  Created by Andrey K. on 24/02/16.
//
//

import Foundation
import CoreData

@objc public enum MMInAppNotificationStyle: Int16 {
	case Modal = 0
	case Banner
}

@objc public enum MMSeenStatus: Int16 {
    case NotSeen = 0
    case SeenNotSent
    case SeenSent
}

enum MMMessageType : Int16 {
	case Default = 0
	case Geo
	case MO
}

@objc public enum MMCampaignState : Int16 {
	case Active = 0
	case Suspended
	case Finished
}

@objc(MessageManagedObject)
final class MessageManagedObject: NSManagedObject, FetchableResult, UpdatableResult {
    var seenStatus: MMSeenStatus {
		get { return MMSeenStatus(rawValue: seenStatusValue) ?? .NotSeen }
		set { seenStatusValue = newValue.rawValue }
    }
	var messageType: MMMessageType {
		get { return MMMessageType(rawValue: messageTypeValue) ?? .Default }
		set { messageTypeValue = newValue.rawValue }
	}
	
	var campaignState: MMCampaignState {
		get { return MMCampaignState(rawValue: campaignStateValue) ?? .Active }
		set { campaignStateValue = newValue.rawValue }
	}
}
