//
//  MMMessage.swift
//  Pods
//
//  Created by Andrey K. on 15/07/16.
//
//

import Foundation
//import SwiftyJSON

public struct MMMessage: MMMessageMetadata, JSONDecodable {
	
	public var hashValue: Int { return messageId.hashValue }
	let isSilent: Bool
	let messageId: String
	let originalPayload: [AnyHashable: AnyObject]
	let customPayload: [AnyHashable: AnyObject]?
	let aps: MMAPS
	let silentData: [String: AnyObject]?
	let geoRegions: [[String: Any]]?
	let interactionsData: [String: AnyObject]?
	var text: String? {
		return aps.text
	}
	
	public init?(json: JSON) {
		if let payload = json.dictionaryObject {
			self.init(payload: payload)
		} else {
			return nil
		}
	}
	
	init?(payload: [AnyHashable: Any]) {
		guard let payload = payload as? [AnyHashable : AnyObject] else {
			return nil
		}
		
		guard let messageId = payload[MMAPIKeys.kMessageId] as? String else {
			return nil
		}
		guard let nativeAPS = payload[MMAPIKeys.kAps] as? [String: AnyObject] else {
			return nil
		}
		
		self.messageId = messageId
		self.isSilent = MMMessage.checkIfSilent(payload: payload)
		if (self.isSilent) {
			if let silentAPS = payload[MMAPIKeys.kInternalData]?[MMAPIKeys.kSilent] as? [String: AnyObject] {
				self.aps = MMAPS.SilentAPS(MMMessage.mergeApsWithSilentParameters(nativeAPS: nativeAPS, silentAPS: silentAPS))
			} else {
				self.aps = MMAPS.NativeAPS(nativeAPS)
			}
		} else {
			self.aps = MMAPS.NativeAPS(nativeAPS)
		}
		self.originalPayload = payload
		self.customPayload = payload[MMAPIKeys.kCustomPayload] as? [String : AnyObject]
		self.silentData = payload[MMAPIKeys.kInternalData]?[MMAPIKeys.kSilent] as? [String : AnyObject]
		self.interactionsData = payload[MMAPIKeys.kInternalData]?[MMAPIKeys.kInteractive] as? [String : AnyObject]
		self.geoRegions = payload[MMAPIKeys.kInternalData]?[MMAPIKeys.kGeo] as? [[String : AnyObject]]
	}
	
	static func checkIfSilent(payload: [AnyHashable: AnyObject]?) -> Bool {
		//if payload APNS originated:
		if (payload?[MMAPIKeys.kInternalData]?[MMAPIKeys.kSilent] as? [String: AnyObject]) != nil {
			return true
		}
		//if payload Server originated:
		return payload?[MMAPIKeys.kSilent] as? Bool ?? false
	}
	
	private static func mergeApsWithSilentParameters(nativeAPS: [String: AnyObject]?, silentAPS: [String: AnyObject]) -> [String: AnyObject] {
		var resultAps = [String: AnyObject]()
		var alert = [String: String]()
		resultAps += nativeAPS
		
		if let body = silentAPS[MMAPIKeys.kBody] as? String {
			alert[MMAPIKeys.kBody] = body
		}
		if let title = silentAPS[MMAPIKeys.kTitle] as? String {
			alert[MMAPIKeys.kTitle] = title
		}
		
		resultAps[MMAPIKeys.kAlert] = alert as AnyObject
		
		if let sound = silentAPS[MMAPIKeys.kSound] as? String {
			resultAps[MMAPIKeys.kSound] = sound as AnyObject
		}
		return resultAps
	}
}

@objc public enum MOMessageSentStatus : Int {
	case Undefined = -1
	case SentSuccessfully = 0
	case SentWithFailure = 1
}

@objc public protocol CustomPayloadSupportedTypes: AnyObject {}
extension NSString: CustomPayloadSupportedTypes {}
extension NSNull: CustomPayloadSupportedTypes {}

public class MOMessage: NSObject {
	public let destination: String?
	public let text: String
	public let customPayload: [String: CustomPayloadSupportedTypes]?
	public let messageId: String
	public let status: MOMessageSentStatus

	public init(destination: String?, text: String, customPayload: [String: CustomPayloadSupportedTypes]?) {
		self.messageId = NSUUID().uuidString
		self.destination = destination
		self.text = text
		self.customPayload = customPayload
		self.status = .Undefined
	}

	var dictRepresentation: [String: Any] {
		var result = [String: Any]()
		
		if let destination = destination {
			result[MMAPIKeys.kMODestination] = destination
		}
		result[MMAPIKeys.kMOText] = text
		result[MMAPIKeys.kMOCustomPayload] = customPayload
		result[MMAPIKeys.kMOMessageId] = messageId
		return result
	}

	convenience init?(json: JSON) {
		if let dictionary = json.dictionaryObject {
			self.init(dictionary: dictionary)
		} else {
			return nil
		}
	}

	init(messageId: String, destination: String?, text: String, customPayload: [String: CustomPayloadSupportedTypes]?) {
		self.messageId = messageId
		self.destination = destination
		self.text = text
		self.customPayload = customPayload
		self.status = .Undefined
	}
	
	private init?(dictionary: [AnyHashable: Any]) {
		guard let messageId = dictionary[MMAPIKeys.kMOMessageId] as? String,
			let text = dictionary[MMAPIKeys.kMOText] as? String,
			let status = dictionary[MMAPIKeys.kMOMessageSentStatusCode] as? Int else
		{
			return nil
		}
		
		self.messageId = messageId
		self.destination = dictionary[MMAPIKeys.kMODestination] as? String
		self.text = text
		self.status = MOMessageSentStatus(rawValue: status) ?? MOMessageSentStatus.Undefined
		self.customPayload = dictionary[MMAPIKeys.kMOCustomPayload] as? [String: CustomPayloadSupportedTypes]
	}
}
