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

enum PushPayloadAPS {
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
	
	var title: String? {
		switch self {
		case .NativeAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["title"] as? String
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["title"] as? String
		}
	}
	
	var loc_key: String? {
		switch self {
		case .NativeAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["loc-key"] as? String
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["loc-key"] as? String
		}
	}
	
	var loc_args: [String]? {
		switch self {
		case .NativeAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["loc-args"] as? [String]
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["loc-args"] as? [String]
		}
	}
	
	var title_loc_key: String? {
		switch self {
		case .NativeAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["title-loc-key"] as? String
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["title-loc-key"] as? String
		}
	}
	
	var title_loc_args: [String]? {
		switch self {
		case .NativeAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["title-loc-args"] as? [String]
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["title-loc-args"] as? [String]
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
	
	public init(messageId: String, direction: MessageDirection, originalPayload: StringKeyPayload) {
		self.messageId = messageId
		self.originalPayload = originalPayload
		self.direction = direction
	}
	
	public override var hash: Int {
		return messageId.hash
	}
	
	public func isEqual(object: AnyObject?) -> Bool {
		return self.messageId == object?.messageId
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
	
	
	/// Title of the message. If message title may be localized ("alert.title-loc-key" attribute is present and refers to an existing localized string), the localized string is returned, otherwise the value of "alert.title" attribute is returned if present.
	public var title: String? { return String.localizedUserNotificationStringOrFallback(key: title_loc_key, args: title_loc_args, fallback: aps.title) }
	
	/// Text of a message. If message may be localized ("alert.loc-key" attribute is present and refers to an existing localized string), the localized string is returned, otherwise the value of "alert.body" attribute is returned if present.
	public var text: String? { return String.localizedUserNotificationStringOrFallback(key: loc_key, args: loc_args, fallback: aps.text) }
	
	/// Localization key of the message title.
	public var title_loc_key: String? { return aps.title_loc_key }
	
	/// Localization args of the message title.
	public var title_loc_args: [String]? { return aps.title_loc_args }
	
	/// Localization key of the message text.
	public var loc_key: String? { return aps.loc_key }
	
	/// Localization args of the message.
	public var loc_args: [String]? { return aps.loc_args }
	
	/// Sound of the message.
	public var sound: String? { return aps.sound }
	
	/// Interactive category Id
	public var category: String? { return aps.category }
	
	public let contentUrl: String?
	public let sendDateTime: TimeInterval // seconds
	public var seenStatus: MMSeenStatus
	public var seenDate: Date?
	public var isDeliveryReportSent: Bool
	public var deliveryReportedDate: Date?
	
	let aps: PushPayloadAPS
	let silentData: StringKeyPayload?
	
	var appliedAction: NotificationAction?
	
	convenience init?(json: JSON) {
		if let payload = json.dictionaryObject {
			self.init(payload: payload)
		} else {
			return nil
		}
		self.deliveryMethod = .pull
	}
	
	/// Initializes the MTMessage from Message storage's message
	convenience init?(messageStorageMessageManagedObject m: Message) {
		self.init(payload: m.payload)
		self.seenStatus = MMSeenStatus(rawValue: m.seenStatusValue) ?? .NotSeen
		self.seenDate = m.seenDate
		self.isDeliveryReportSent = m.isDeliveryReportSent
		self.deliveryReportedDate = m.deliveryReportedDate
	}
	
    /// Initializes the MTMessage from original payload.
	public init?(payload: APNSPayload) {
		guard var payload = payload as? StringKeyPayload, let messageId = payload[APNSPayloadKeys.messageId] as? String, let nativeAPS = payload[APNSPayloadKeys.aps] as? StringKeyPayload else {
			return nil
		}
		
		self.isSilent = MTMessage.isSilent(payload: payload)
		if (self.isSilent) {
			if let silentAPS = (payload[APNSPayloadKeys.internalData] as? StringKeyPayload)?[InternalDataKeys.silent] as? StringKeyPayload {
				self.aps = PushPayloadAPS.SilentAPS(MTMessage.apsByMerging(nativeAPS: nativeAPS, withSilentAPS: silentAPS))
			} else {
				self.aps = PushPayloadAPS.NativeAPS(nativeAPS)
			}
		} else {
			self.aps = PushPayloadAPS.NativeAPS(nativeAPS)
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
		if let sendDateTimeMillis = (payload[APNSPayloadKeys.internalData] as? StringKeyPayload)?[InternalDataKeys.sendDateTime] as? Double {
			self.sendDateTime = sendDateTimeMillis/1000
		} else {
			self.sendDateTime = Date().timeIntervalSince1970
		}
		//workaround for cordova
		self.isMessageLaunchingApplication = payload[ApplicationLaunchedByNotification_Key] != nil
		payload.removeValue(forKey: ApplicationLaunchedByNotification_Key)
		
		
		if let atts = internData?[InternalDataKeys.attachments] as? [StringKeyPayload], let firstOne = atts.first {
			self.contentUrl = firstOne[AttachmentsKeys.url] as? String
		} else {
			self.contentUrl = nil
		}
		super.init(messageId: messageId, direction: .MT, originalPayload: payload)
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
    var bulkId: String? {get}
    var initialMessageId: String? {get}
}

struct MOAttributes: MOMessageAttributes {
	let destination: String?
	let text: String
	let customPayload: [String: CustomPayloadSupportedTypes]?
	let messageId: String
	let sentStatus: MOMessageSentStatus
    let bulkId: String?
    let initialMessageId: String?
	
	var dictRepresentation: DictionaryRepresentation {
		var result = DictionaryRepresentation()
		result[APIKeys.kMODestination] = destination
		result[APIKeys.kMOText] = text
		result[APIKeys.kMOCustomPayload] = customPayload
		result[APIKeys.kMOMessageId] = messageId
		result[APIKeys.kMOMessageSentStatusCode] = NSNumber(value: sentStatus.rawValue)
        result[APIKeys.kMOBulkId] = bulkId
        result[APIKeys.kMOInitialMessageId] = initialMessageId
		return result
	}
}

public class MOMessage: BaseMessage, MOMessageAttributes {
	public let destination: String?
	public let text: String
	public let customPayload: [String: CustomPayloadSupportedTypes]?
	public let sentStatus: MOMessageSentStatus
	public let composedDate: Date
    public let bulkId: String?
    public let initialMessageId: String?
	
    convenience public init(destination: String?, text: String, customPayload: [String: CustomPayloadSupportedTypes]?, composedDate: Date, bulkId: String? = nil, initialMessageId: String? = nil) {
		let mId = NSUUID().uuidString
        self.init(messageId: mId, destination: destination, text: text, customPayload: customPayload, composedDate: composedDate, bulkId: bulkId, initialMessageId: initialMessageId)
	}

	/// Iitializes the MOMessage from Message storage's message
	convenience init?(messageStorageMessageManagedObject m: Message) {
		self.init(payload: m.payload, composedDate: m.createdDate)
	}
	
	convenience init?(messageManagedObject: MessageManagedObject) {
		if let p = messageManagedObject.payload {
			self.init(payload: p, composedDate: messageManagedObject.creationDate)
		} else {
			return nil
		}
	}
	
	convenience init?(json: JSON) {
		if let dictionary = json.dictionaryObject {
			self.init(payload: dictionary, composedDate: MobileMessaging.date.now) // workaround: `now` is put as a composed date only because there is no Composed Date field in a JSON model. however this data is not used from anywhere in SDK.
		} else {
			return nil
		}
	}

	init(messageId: String, destination: String?, text: String, customPayload: [String: CustomPayloadSupportedTypes]?, composedDate: Date, bulkId: String? = nil, initialMessageId: String? = nil) {
		self.destination = destination
		self.customPayload = customPayload
		self.sentStatus = .Undefined
		self.text = text
		self.composedDate = composedDate
        self.bulkId = bulkId
        self.initialMessageId = initialMessageId
        
		let dict = MOAttributes(destination: destination, text: text, customPayload: customPayload, messageId: messageId, sentStatus: self.sentStatus, bulkId: bulkId, initialMessageId: initialMessageId).dictRepresentation
		super.init(messageId: messageId, direction: .MO, originalPayload: dict)
	}
	
	var dictRepresentation: DictionaryRepresentation {
		return MOAttributes(destination: destination, text: text, customPayload: customPayload, messageId: messageId, sentStatus: sentStatus, bulkId: bulkId, initialMessageId: initialMessageId).dictRepresentation
	}
	
	init?(payload: DictionaryRepresentation, composedDate: Date) {
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
		self.composedDate = composedDate
        self.bulkId = payload[APIKeys.kMOBulkId] as? String
        self.initialMessageId = payload[APIKeys.kMOInitialMessageId] as? String
		let dict = MOAttributes(destination: destination, text: text, customPayload: customPayload, messageId: messageId, sentStatus: self.sentStatus, bulkId: bulkId, initialMessageId: initialMessageId).dictRepresentation
		super.init(messageId: messageId, direction: .MO, originalPayload: dict)
	}
}
