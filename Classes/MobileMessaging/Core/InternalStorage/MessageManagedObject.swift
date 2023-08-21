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

public enum MMMessageType : Int16 {
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
final public class MessageManagedObject: NSManagedObject, FetchableResult, UpdatableResult {
    public var seenStatus: MMSeenStatus {
		get { return MMSeenStatus(rawValue: seenStatusValue) ?? .NotSeen }
		set { seenStatusValue = newValue.rawValue }
    }
	public var messageType: MMMessageType {
		get { return MMMessageType(rawValue: messageTypeValue) ?? .Default }
		set { messageTypeValue = newValue.rawValue }
	}
	
	public var campaignState: MMCampaignState {
		get { return MMCampaignState(rawValue: campaignStateValue) ?? .Active }
		set { campaignStateValue = newValue.rawValue }
	}
}
