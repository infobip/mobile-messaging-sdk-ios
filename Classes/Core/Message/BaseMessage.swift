//
//  BaseMessage.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 18/10/2017.
//

import Foundation

protocol MessageProtocol {
	/// Indicates whether the message is incoming (MT) or outgoing (MO)
	var direction: MessageDirection {get}
	
	/// Message id
	var messageId: String {get}
	
	/// Original message payload
	var originalPayload: StringKeyPayload {get}
	
	/// Text of the message
	var text: String? {get set}
	
	/// Custom data
	var customPayload: StringKeyPayload? {get}
	
	/// Indicates whether the message is chat message
	var isChatMessage: Bool {get}
	
	/// Defines the origin of a message.
	///
	/// Message may be either pushed by APNS, generated locally or pulled from the server.
	var deliveryMethod: MessageDeliveryMethod {get}
}

@objcMembers
public class BaseMessage: NSObject, MessageProtocol {
	
	public var customPayload: StringKeyPayload?
	
	public var direction: MessageDirection
	
	public var messageId: String
	
	public var originalPayload: StringKeyPayload
	
	public var deliveryMethod: MessageDeliveryMethod
	
	public var text: String?
	
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

