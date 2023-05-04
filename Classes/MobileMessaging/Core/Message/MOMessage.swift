//
//  MOMessage.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 18/10/2017.
//

import Foundation

@objcMembers
public class MM_MOMessage: MMBaseMessage {
	/// Destination indicates where the message is being sent
	public var destination: String?

	/// Sent status
	public var sentStatus: MM_MOMessageSentStatus

	/// Indicates when the message was composed
	public var composedDate: Date

	/// Indicates the bulk id that the message was sent within
	public var bulkId: String?

	/// Indicates id of the associated message
	public var initialMessageId: String?
	
	var dictRepresentation: DictionaryRepresentation {
		return MOAttributes(destination: destination, text: text ?? "", customPayload: customPayload, messageId: messageId, sentStatus: sentStatus, bulkId: bulkId, initialMessageId: initialMessageId).dictRepresentation
	}
	
	convenience public init(destination: String?, text: String, customPayload: [String: MMCustomPayloadSupportedTypes]?, composedDate: Date, bulkId: String? = nil, initialMessageId: String? = nil) {
		let mId = NSUUID().uuidString
		self.init(messageId: mId, destination: destination, text: text, customPayload: customPayload, composedDate: composedDate, bulkId: bulkId, initialMessageId: initialMessageId, deliveryMethod: .generatedLocally)
	}
	
	convenience init?(messageStorageMessageManagedObject m: Message) {
		self.init(payload: m.payload, composedDate: m.createdDate)
		self.sentStatus = MM_MOMessageSentStatus(rawValue: m.sentStatusValue) ?? .Undefined //FIXME: proper init needed, move the sent status out of designated inits. also check mt mtessages if all specific attributes are initialized @NSManaged var messageId: String
	}
	
	convenience init?(messageManagedObject: MessageManagedObject) {
		if let p = messageManagedObject.payload {
			self.init(payload: p, composedDate: messageManagedObject.creationDate)
		} else {
			return nil
		}
	}
	
	convenience init?(moResponseJson json: JSON) {
		if let dictionary = json.dictionaryObject {
			self.init(payload: dictionary, composedDate: MobileMessaging.date.now) // workaround: `now` is put as a composed date only because there is no Composed Date field in a JSON model. however this data is not used from anywhere in SDK.
		} else {
			return nil
		}
	}
	
	convenience init?(payload: DictionaryRepresentation, composedDate: Date) {
		guard let messageId = payload[Consts.APIKeys.MO.messageId] as? String,
			let text = payload[Consts.APIKeys.MO.text] as? String,
			let status = payload[Consts.APIKeys.MO.messageSentStatusCode] as? Int else
		{
			return nil
		}
		let sentStatus = MM_MOMessageSentStatus(rawValue: Int16(status)) ?? MM_MOMessageSentStatus.Undefined
		let destination = payload[Consts.APIKeys.MO.destination] as? String
		let customPayload = payload[Consts.APIKeys.MO.customPayload] as? [String: MMCustomPayloadSupportedTypes]
		let bulkId = payload[Consts.APIKeys.MO.bulkId] as? String
		let initialMessageId = payload[Consts.APIKeys.MO.initialMessageId] as? String
		
		self.init(messageId: messageId, destination: destination, text: text, customPayload: customPayload, composedDate: composedDate, bulkId: bulkId, initialMessageId: initialMessageId, sentStatus: sentStatus, deliveryMethod: .pull)
	}
	
	init(messageId: String, destination: String?, text: String, customPayload: [String: MMCustomPayloadSupportedTypes]?, composedDate: Date, bulkId: String? = nil, initialMessageId: String? = nil, sentStatus: MM_MOMessageSentStatus = .Undefined, deliveryMethod: MMMessageDeliveryMethod) {
		let payload = MOAttributes(	destination: destination,
									   text: text,
									   customPayload: customPayload,
									   messageId: messageId,
									   sentStatus: sentStatus,
									   bulkId: bulkId,
									   initialMessageId: initialMessageId).dictRepresentation
		
		
		self.sentStatus = sentStatus
		self.destination = destination
		self.composedDate = composedDate
		self.bulkId = bulkId
		self.initialMessageId = initialMessageId
		
		super.init(messageId: messageId, direction: .MO, originalPayload: payload, deliveryMethod: deliveryMethod)
		
		self.text = text
	}
}
