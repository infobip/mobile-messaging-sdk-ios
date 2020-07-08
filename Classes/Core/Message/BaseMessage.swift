//
//  BaseMessage.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 18/10/2017.
//

import Foundation

@objcMembers
public class BaseMessage: NSObject {

	/// Custom data
	public var customPayload: StringKeyPayload?

	/// Indicates whether the message is incoming (MT) or outgoing (MO)
	public var direction: MessageDirection

	/// Message id
	public var messageId: String

	/// Original message payload
	public var originalPayload: StringKeyPayload

	/// Defines the origin of a message.
	///
	/// Message may be either pushed by APNS, generated locally or pulled from the server.
	public var deliveryMethod: MessageDeliveryMethod

	/// Text of the message
	public var text: String?

	/// Indicates whether the message is chat message
	public var isChatMessage: Bool {
		return false
	}
	
	class func makeMessage(withMessageStorageMessageManagedObject m: Message) -> BaseMessage? {
		guard let direction = MessageDirection(rawValue: m.direction) else {
			return nil
		}
		switch direction {
		case .MO:
			return MOMessage(messageStorageMessageManagedObject: m)
		case .MT:
			return MTMessage(messageStorageMessageManagedObject: m)
		}
	}
	
	// designated init
	public init(messageId: String, direction: MessageDirection, originalPayload: StringKeyPayload, deliveryMethod: MessageDeliveryMethod) {
		self.messageId = messageId
		self.originalPayload = originalPayload
		self.direction = direction
		self.deliveryMethod = deliveryMethod
		self.customPayload = originalPayload[Consts.APNSPayloadKeys.customPayload] as? [String: CustomPayloadSupportedTypes]
	}
	
	public func isEqual(object: Any?) -> Bool {
		guard let otherMessage = object as? BaseMessage else {
			return false
		}
		return self.messageId == otherMessage.messageId
	}
}

