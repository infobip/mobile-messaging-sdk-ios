//
//  MMMessage.swift
//
//  Created by Andrey K. on 15/07/16.
//
//

import Foundation
import SwiftyJSON

@objc public enum MessageDeliveryMethod: Int16 {
	case undefined = 0, push, pull
}

@objc public enum MessageDirection: Int16 {
	case MT = 0, MO
}

public typealias APNSPayload = [AnyHashable: Any]
public typealias StringKeyPayload = [String: Any]

enum MMAPS {
	case SilentAPS([AnyHashable: Any])
	case NativeAPS([AnyHashable: Any])
	
	var badge: Int? {
		switch self {
		case .NativeAPS(let dict):
			return dict["badge"] as? Int
		case .SilentAPS(let dict):
			return dict["badge"] as? Int
		}
	}
	
	var sound: String? {
		switch self {
		case .NativeAPS(let dict):
			return dict["sound"] as? String
		case .SilentAPS(let dict):
			return dict["sound"] as? String
		}
	}
	
	var text: String? {
		switch self {
		case .NativeAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["body"] as? String
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["body"] as? String
		}
	}
}


protocol MMMessageMetadata: Hashable {
	var isSilent: Bool {get}
	var messageId: String {get}
}

public class BaseMessage: NSObject {
	public let messageId: String
	public let direction: MessageDirection
	public let originalPayload: StringKeyPayload
	public let createdDate: Date
	
	class func makeMessage(coreDataMessage: Message) -> BaseMessage? {
		guard let direction = MessageDirection(rawValue: coreDataMessage.direction) else {
			return nil
		}
		switch direction {
		case .MO:
			return MOMessage(coreDataMessage: coreDataMessage)
		case .MT:
			return MTMessage(coreDataMessage: coreDataMessage)
		}
	}
	
	public init(messageId: String, direction: MessageDirection, originalPayload: StringKeyPayload, createdDate: Date) {
		self.messageId = messageId
		self.originalPayload = originalPayload
		self.direction = direction
		self.createdDate = createdDate
	}
	
	public override var hash: Int {
		return messageId.hash
	}
	
	public func isEqual(object: AnyObject?) -> Bool {
		return self.hash == object?.hash
	}
}

func ==(lhs: MTMessage, rhs: MTMessage) -> Bool {
	return lhs.messageId == rhs.messageId
}

/// Incapsulates all the attributes related to the remote notifications.
public class MTMessage: BaseMessage, MMMessageMetadata, JSONDecodable {
	
	/// Defines the origin of a message.
	///
	/// Message may be either pushed by APNS or pulled from the server.
	public private(set) var deliveryMethod: MessageDeliveryMethod
	
	/// Defines if a message is silent. Silent messages have neither text nor sound attributes.
	public let isSilent: Bool
	
	/// Custom message payload.
	///
	/// See also: [Custom message payload](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Custom-message-payload)
	public let customPayload: StringKeyPayload?
	
	/// Text of a message.
	public var text: String? {
		return aps.text
	}
	
	/// Sound of a message.
	public var sound: String? {
		return aps.sound
	}
	
	public var seenStatus: MMSeenStatus
	public var isDeliveryReportSent: Bool
	
	let aps: MMAPS
	let silentData: StringKeyPayload?
	
	convenience required public init?(json: JSON) {
		if let payload = json.dictionaryObject {
			self.init(payload: payload, createdDate: Date())
		} else {
			return nil
		}
		self.deliveryMethod = .pull
	}
	
	convenience init?(coreDataMessage: Message) {
		self.init(payload: coreDataMessage.payload, createdDate: coreDataMessage.createdDate)
		self.seenStatus = MMSeenStatus(rawValue: coreDataMessage.seenStatusValue) ?? .NotSeen
		self.isDeliveryReportSent = coreDataMessage.isDeliveryReportSent
	}
	
	init?(payload: APNSPayload, createdDate: Date) {
		guard let payload = payload as? StringKeyPayload, let messageId = payload[APNSPayloadKeys.kMessageId] as? String, let nativeAPS = payload[APNSPayloadKeys.kAps] as? StringKeyPayload else {
			return nil
		}
		
		self.isSilent = MTMessage.isSilent(payload: payload)
		if (self.isSilent) {
			if let silentAPS = (payload[APNSPayloadKeys.kInternalData] as? StringKeyPayload)?[APNSPayloadKeys.kInternalDataSilent] as? StringKeyPayload {
				self.aps = MMAPS.SilentAPS(MTMessage.apsByMerging(nativeAPS: nativeAPS, withSilentAPS: silentAPS))
			} else {
				self.aps = MMAPS.NativeAPS(nativeAPS)
			}
		} else {
			self.aps = MMAPS.NativeAPS(nativeAPS)
		}

		//TODO: refactor all these `as` by extending Dictionary.
		self.customPayload = payload[APNSPayloadKeys.kCustomPayload] as? StringKeyPayload
		self.silentData = (payload[APNSPayloadKeys.kInternalData] as? StringKeyPayload)?[APNSPayloadKeys.kInternalDataSilent] as? StringKeyPayload
		self.deliveryMethod = .push
		self.seenStatus = .NotSeen
		self.isDeliveryReportSent = false
		super.init(messageId: messageId, direction: .MT, originalPayload: payload, createdDate: createdDate)
	}
	
	private static func isSilent(payload: APNSPayload?) -> Bool {
		//if payload APNS originated:
		if ((payload?[APNSPayloadKeys.kInternalData] as? [AnyHashable: Any])?[APNSPayloadKeys.kInternalDataSilent] as? [AnyHashable: Any]) != nil {
			return true
		}
		//if payload Server originated:
		return payload?[APNSPayloadKeys.kInternalDataSilent] as? Bool ?? false
	}
	
	private static func apsByMerging(nativeAPS: StringKeyPayload?, withSilentAPS silentAPS: StringKeyPayload) -> StringKeyPayload {
		var resultAps = nativeAPS ?? StringKeyPayload()
		var alert = StringKeyPayload()
		
		if let body = silentAPS[APNSPayloadKeys.kBody] as? String {
			alert[APNSPayloadKeys.kBody] = body
		}
		if let title = silentAPS[APNSPayloadKeys.kTitle] as? String {
			alert[APNSPayloadKeys.kTitle] = title
		}
		
		resultAps[APNSPayloadKeys.kAlert] = alert
		
		if let sound = silentAPS[APNSPayloadKeys.kSound] as? String {
			resultAps[APNSPayloadKeys.kSound] = sound
		}
		return resultAps
	}
}

class MMMessageFactory {
	class func makeMessage(with payload: APNSPayload, createdDate: Date) -> MTMessage? {
		return MMGeoMessage.init(payload: payload, createdDate: createdDate) ?? MTMessage.init(payload: payload, createdDate: createdDate)
	}
	class func makeMessage(with json: JSON) -> MTMessage? {
		return MMGeoMessage.init(json: json) ?? MTMessage.init(json: json)
	}
}

@objc public enum MOMessageSentStatus : Int16 {
	case Undefined = -1
	case SentSuccessfully = 0
	case SentWithFailure = 1
}

@objc public protocol CustomPayloadSupportedTypes: AnyObject {}
extension NSString: CustomPayloadSupportedTypes {}
extension NSNull: CustomPayloadSupportedTypes {}

protocol MOMessageAttributes {
	var destination: String? {get}
	var text: String {get}
	var customPayload: [String: CustomPayloadSupportedTypes]? {get}
	var messageId: String {get}
	var sentStatus: MOMessageSentStatus {get}
}

struct MOAttributes: MOMessageAttributes {
	let destination: String?
	let text: String
	let customPayload: [String: CustomPayloadSupportedTypes]?
	let messageId: String
	let sentStatus: MOMessageSentStatus
	
	var dictRepresentation: DictionaryRepresentation {
		var result = DictionaryRepresentation()
		result[MMAPIKeys.kMODestination] = destination
		result[MMAPIKeys.kMOText] = text
		result[MMAPIKeys.kMOCustomPayload] = customPayload
		result[MMAPIKeys.kMOMessageId] = messageId
		result[MMAPIKeys.kMOMessageSentStatusCode] = NSNumber(value: sentStatus.rawValue)
		return result
	}
}

public class MOMessage: BaseMessage, MOMessageAttributes {
	public let destination: String?
	public let text: String
	public let customPayload: [String: CustomPayloadSupportedTypes]?
	public let sentStatus: MOMessageSentStatus
	
	public init(destination: String?, text: String, customPayload: [String: CustomPayloadSupportedTypes]?) {
		self.destination = destination
		self.sentStatus = .Undefined
		self.customPayload = customPayload
		self.text = text
		
		let mId = NSUUID().uuidString
		let dict = MOAttributes(destination: destination, text: text, customPayload: customPayload, messageId: mId, sentStatus: .Undefined).dictRepresentation
		super.init(messageId: mId, direction: .MO, originalPayload: dict, createdDate: Date())
	}

	convenience init?(coreDataMessage: Message) {
		self.init(payload: coreDataMessage.payload)
	}
	
	convenience init?(json: JSON) {
		if let dictionary = json.dictionaryObject {
			self.init(payload: dictionary)
		} else {
			return nil
		}
	}

	init(messageId: String, destination: String?, text: String, customPayload: [String: CustomPayloadSupportedTypes]?) {
		self.destination = destination
		self.customPayload = customPayload
		self.sentStatus = .Undefined
		self.text = text
		
		let dict = MOAttributes(destination: destination, text: text, customPayload: customPayload, messageId: messageId, sentStatus: self.sentStatus).dictRepresentation
		super.init(messageId: messageId, direction: .MO, originalPayload: dict, createdDate: Date())
	}
	
	var dictRepresentation: DictionaryRepresentation {
		return MOAttributes(destination: destination, text: text, customPayload: customPayload, messageId: messageId, sentStatus: sentStatus).dictRepresentation
	}
	
	init?(payload: DictionaryRepresentation) {
		guard let messageId = payload[MMAPIKeys.kMOMessageId] as? String,
			let text = payload[MMAPIKeys.kMOText] as? String,
			let status = payload[MMAPIKeys.kMOMessageSentStatusCode] as? Int else
		{
			return nil
		}
	
		self.destination = payload[MMAPIKeys.kMODestination] as? String
		self.sentStatus = MOMessageSentStatus(rawValue: Int16(status)) ?? MOMessageSentStatus.Undefined
		self.customPayload = payload[MMAPIKeys.kMOCustomPayload] as? [String: CustomPayloadSupportedTypes]
		self.text = text
		
		let dict = MOAttributes(destination: destination, text: text, customPayload: customPayload, messageId: messageId, sentStatus: self.sentStatus).dictRepresentation
		super.init(messageId: messageId, direction: .MO, originalPayload: dict, createdDate: Date())
	}
}
