//
//  MMMessage.swift
//
//  Created by Andrey K. on 15/07/16.
//
//

import Foundation

@objc public enum MessageDeliveryMethod: Int16 {
	case undefined = 0, push, pull, generatedLocally
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
	var category: String? {
		switch self {
		case .NativeAPS(let dict):
			return dict["category"] as? String
		case .SilentAPS(let dict):
			return dict["category"] as? String
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
	public var originalPayload: StringKeyPayload
	public let createdDate: Date
	
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
public class MTMessage: BaseMessage, MMMessageMetadata {
	
	/// Defines the origin of a message.
	///
	/// Message may be either pushed by APNS, generated locally or pulled from the server.
	public internal(set) var deliveryMethod: MessageDeliveryMethod
	
	/// Defines if a message is silent. Silent messages have neither text nor sound attributes.
	public let isSilent: Bool
	
	/// Custom message payload.
	///
	/// See also: [Custom message payload](https://github.com/infobip/mobile-messaging-sdk-ios/wiki/Custom-message-payload)
	public let customPayload: StringKeyPayload?
    
    let internalData: StringKeyPayload?
	
	/// Text of a message.
	public var text: String? {
		return aps.text
	}
	
	/// Sound of a message.
	public var sound: String? {
		return aps.sound
	}
	
	/// Interactive category Id
	public var category: String? {
		return aps.category
	}
	
	public let contentUrl: String?
	
	public var seenStatus: MMSeenStatus
	public var seenDate: Date?
	public var isDeliveryReportSent: Bool
	public var deliveryReportedDate: Date?
	
	let aps: MMAPS
	let silentData: StringKeyPayload?
	
	var interactiveActionClicked: MMNotificationAction?
	
	convenience init?(json: JSON) {
		if let payload = json.dictionaryObject {
			self.init(payload: payload, createdDate: MobileMessaging.date.now)
		} else {
			return nil
		}
		self.deliveryMethod = .pull
	}
	
	/// Iitializes the MTMessage from Message storage's message
	convenience init?(messageStorageMessageManagedObject m: Message) {
		self.init(payload: m.payload, createdDate: m.createdDate)
		self.seenStatus = MMSeenStatus(rawValue: m.seenStatusValue) ?? .NotSeen
		self.seenDate = m.seenDate
		self.isDeliveryReportSent = m.isDeliveryReportSent
		self.deliveryReportedDate = m.deliveryReportedDate
	}
	
	init?(payload: APNSPayload, createdDate: Date) {
		guard var payload = payload as? StringKeyPayload, let messageId = payload[APNSPayloadKeys.messageId] as? String, let nativeAPS = payload[APNSPayloadKeys.aps] as? StringKeyPayload else {
			return nil
		}
		
		self.isSilent = MTMessage.isSilent(payload: payload)
		if (self.isSilent) {
			if let silentAPS = (payload[APNSPayloadKeys.internalData] as? StringKeyPayload)?[InternalDataKeys.silent] as? StringKeyPayload {
				self.aps = MMAPS.SilentAPS(MTMessage.apsByMerging(nativeAPS: nativeAPS, withSilentAPS: silentAPS))
			} else {
				self.aps = MMAPS.NativeAPS(nativeAPS)
			}
		} else {
			self.aps = MMAPS.NativeAPS(nativeAPS)
		}

		let internData = payload[APNSPayloadKeys.internalData] as? StringKeyPayload
		self.customPayload = payload[APNSPayloadKeys.customPayload] as? StringKeyPayload
        self.internalData = internData
		self.silentData = internData?[InternalDataKeys.silent] as? StringKeyPayload
		self.deliveryMethod = .push
		self.seenStatus = .NotSeen
		self.seenDate = nil
		self.isDeliveryReportSent = false
		self.deliveryReportedDate = nil
		
		//workaround for cordova
		self.isMessageLaunchingApplication = payload[ApplicationLaunchedByNotification_Key] != nil
		payload.removeValue(forKey: ApplicationLaunchedByNotification_Key)
		
		
		if let atts = internData?[InternalDataKeys.attachments] as? [StringKeyPayload], let firstOne = atts.first {
			self.contentUrl = firstOne[AttachmentsKeys.url] as? String
		} else {
			self.contentUrl = nil
		}
		super.init(messageId: messageId, direction: .MT, originalPayload: payload, createdDate: createdDate)
	}
	
	private static func isSilent(payload: APNSPayload?) -> Bool {
		//if payload APNS originated:
		if ((payload?[APNSPayloadKeys.internalData] as? [AnyHashable: Any])?[InternalDataKeys.silent] as? [AnyHashable: Any]) != nil {
			return true
		}
		//if payload Server originated:
		return payload?[InternalDataKeys.silent] as? Bool ?? false
	}
	
	private static func apsByMerging(nativeAPS: StringKeyPayload?, withSilentAPS silentAPS: StringKeyPayload) -> StringKeyPayload {
		var resultAps = nativeAPS ?? StringKeyPayload()
		var alert = StringKeyPayload()
		
		if let body = silentAPS[APNSPayloadKeys.body] as? String {
			alert[APNSPayloadKeys.body] = body
		}
		if let title = silentAPS[APNSPayloadKeys.title] as? String {
			alert[APNSPayloadKeys.title] = title
		}
		
		resultAps[APNSPayloadKeys.alert] = alert
		
		if let sound = silentAPS[APNSPayloadKeys.sound] as? String {
			resultAps[APNSPayloadKeys.sound] = sound
		}
		return resultAps
	}
	
	var isGeoSignalingMessage: Bool {
		//TODO: this is a workaround. MobileMessaging must not know anything about geofencing feature. message type attriute needed?
		return internalData?[InternalDataKeys.geo] != nil && isSilent
	}
	
	let isMessageLaunchingApplication: Bool
}

@objc public enum MOMessageSentStatus : Int16 {
	case Undefined = -1
	case SentSuccessfully = 0
	case SentWithFailure = 1
}

@objc public protocol CustomPayloadSupportedTypes: AnyObject {}
extension NSString: CustomPayloadSupportedTypes {}
extension NSNull: CustomPayloadSupportedTypes {}
extension NSNumber: CustomPayloadSupportedTypes {}

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
		result[APIKeys.kMODestination] = destination
		result[APIKeys.kMOText] = text
		result[APIKeys.kMOCustomPayload] = customPayload
		result[APIKeys.kMOMessageId] = messageId
		result[APIKeys.kMOMessageSentStatusCode] = NSNumber(value: sentStatus.rawValue)
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
		super.init(messageId: mId, direction: .MO, originalPayload: dict, createdDate: MobileMessaging.date.now)
	}

	/// Iitializes the MOMessage from Message storage's message
	convenience init?(messageStorageMessageManagedObject m: Message) {
		self.init(payload: m.payload)
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
		super.init(messageId: messageId, direction: .MO, originalPayload: dict, createdDate: MobileMessaging.date.now)
	}
	
	var dictRepresentation: DictionaryRepresentation {
		return MOAttributes(destination: destination, text: text, customPayload: customPayload, messageId: messageId, sentStatus: sentStatus).dictRepresentation
	}
	
	init?(payload: DictionaryRepresentation) {
		guard let messageId = payload[APIKeys.kMOMessageId] as? String,
			let text = payload[APIKeys.kMOText] as? String,
			let status = payload[APIKeys.kMOMessageSentStatusCode] as? Int else
		{
			return nil
		}
	
		self.destination = payload[APIKeys.kMODestination] as? String
		self.sentStatus = MOMessageSentStatus(rawValue: Int16(status)) ?? MOMessageSentStatus.Undefined
		self.customPayload = payload[APIKeys.kMOCustomPayload] as? [String: CustomPayloadSupportedTypes]
		self.text = text
		
		let dict = MOAttributes(destination: destination, text: text, customPayload: customPayload, messageId: messageId, sentStatus: self.sentStatus).dictRepresentation
		super.init(messageId: messageId, direction: .MO, originalPayload: dict, createdDate: MobileMessaging.date.now)
	}
}
