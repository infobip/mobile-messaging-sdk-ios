//
//  BaseMessage.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 18/10/2017.
//

import Foundation

@objcMembers
open class MMBaseMessage: NSObject {

	/// Custom data
	public var customPayload: MMStringKeyPayload?

	/// Indicates whether the message is incoming (MT) or outgoing (MO)
	public var direction: MMMessageDirection

	/// Message id
	public var messageId: String

	/// Original message payload
	public var originalPayload: MMStringKeyPayload

	/// Defines the origin of a message.
	///
	/// Message may be either pushed by APNS, generated locally or pulled from the server.
	public var deliveryMethod: MMMessageDeliveryMethod

	/// Text of the message
	public var text: String?

	/// Indicates whether the message is chat message
	public var isChatMessage: Bool {
		return false
	}
	
	class func makeMessage(withMessageStorageMessageManagedObject m: Message) -> MMBaseMessage? {
		guard let direction = MMMessageDirection(rawValue: m.direction) else {
			return nil
		}
		switch direction {
		case .MO:
			return MM_MOMessage(messageStorageMessageManagedObject: m)
		case .MT:
			return MM_MTMessage(messageStorageMessageManagedObject: m)
		}
	}
	
	// designated init
	public init(messageId: String, direction: MMMessageDirection, originalPayload: MMStringKeyPayload, deliveryMethod: MMMessageDeliveryMethod) {
		self.messageId = messageId
		self.originalPayload = originalPayload
		self.direction = direction
		self.deliveryMethod = deliveryMethod
		self.customPayload = originalPayload[Consts.APNSPayloadKeys.customPayload] as? [String: MMCustomPayloadSupportedTypes]
	}
	
	public func isEqual(object: Any?) -> Bool {
		guard let otherMessage = object as? MMBaseMessage else {
			return false
		}
		return self.messageId == otherMessage.messageId
	}
}

