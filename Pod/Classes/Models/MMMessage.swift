//
//  MMMessage.swift
//
//  Created by Andrey K. on 15/07/16.
//
//

import Foundation
import SwiftyJSON

typealias APNSPayload = [NSObject: AnyObject]
typealias StringKeyPayload = [String: AnyObject]

struct MMMessage: MMMessageMetadata, JSONDecodable {
	var hashValue: Int { return messageId.hashValue }
	let isSilent: Bool
	let messageId: String
	let originalPayload: StringKeyPayload
	let customPayload: StringKeyPayload?
	let aps: MMAPS
	let silentData: StringKeyPayload?
	let geoRegions: [StringKeyPayload]?
	var text: String? {
		return aps.text
	}
	
	init?(json: JSON) {
		if let payload = json.dictionaryObject {
			self.init(payload: payload)
		} else {
			return nil
		}
	}
	
	init?(payload: APNSPayload) {
		guard let payload = payload as? StringKeyPayload, let messageId = payload[MMAPIKeys.kMessageId] as? String, let nativeAPS = payload[MMAPIKeys.kAps] as? StringKeyPayload else {
			return nil
		}
		
		self.messageId = messageId
		self.isSilent = MMMessage.isSilent(payload)
		if (self.isSilent) {
			if let silentAPS = payload[MMAPIKeys.kInternalData]?[MMAPIKeys.kSilent] as? StringKeyPayload {
				self.aps = MMAPS.SilentAPS(MMMessage.apsByMerging(nativeAPS: nativeAPS, withSilentAPS: silentAPS))
			} else {
				self.aps = MMAPS.NativeAPS(nativeAPS)
			}
		} else {
			self.aps = MMAPS.NativeAPS(nativeAPS)
		}
		self.originalPayload = payload
		//TODO: refactor all these `as` by extending Dictionary.
		self.customPayload = payload[MMAPIKeys.kCustomPayload] as? StringKeyPayload
		self.silentData = payload[MMAPIKeys.kInternalData]?[MMAPIKeys.kSilent] as? StringKeyPayload
		self.geoRegions = payload[MMAPIKeys.kInternalData]?[MMAPIKeys.kGeo] as? [StringKeyPayload]
	}
	
	private static func isSilent(payload: [NSObject: AnyObject]?) -> Bool {
		//if payload APNS originated:
		if (payload?[MMAPIKeys.kInternalData]?[MMAPIKeys.kSilent] as? [String: AnyObject]) != nil {
			return true
		}
		//if payload Server originated:
		return payload?[MMAPIKeys.kSilent] as? Bool ?? false
	}
	
	private static func apsByMerging(nativeAPS nativeAPS: StringKeyPayload?, withSilentAPS silentAPS: StringKeyPayload) -> StringKeyPayload {
		var resultAps = nativeAPS ?? StringKeyPayload()
		var alert = StringKeyPayload()
		
		if let body = silentAPS[MMAPIKeys.kBody] as? String {
			alert[MMAPIKeys.kBody] = body
		}
		if let title = silentAPS[MMAPIKeys.kTitle] as? String {
			alert[MMAPIKeys.kTitle] = title
		}
		
		resultAps[MMAPIKeys.kAlert] = alert
		
		if let sound = silentAPS[MMAPIKeys.kSound] as? String {
			resultAps[MMAPIKeys.kSound] = sound
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
		self.messageId = NSUUID().UUIDString
		self.destination = destination
		self.text = text
		self.customPayload = customPayload
		self.status = .Undefined
	}

	var dictRepresentation: [String: AnyObject] {
		var result = [String: AnyObject]()
		result[MMAPIKeys.kMODestination] = destination
		result[MMAPIKeys.kMOText] = text
		result[MMAPIKeys.kMOCustomPayload] = customPayload
		result[MMAPIKeys.kMOMessageId] = messageId
		return result
	}

	convenience init?(json: JSON) {
		if let dictionary = json.dictionaryObject {
			self.init(jsonDictionary: dictionary)
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
	
	private init?(jsonDictionary: [String: AnyObject]) {
		guard let messageId = jsonDictionary[MMAPIKeys.kMOMessageId] as? String,
			let text = jsonDictionary[MMAPIKeys.kMOText] as? String,
			let status = jsonDictionary[MMAPIKeys.kMOMessageSentStatusCode] as? Int else
		{
			return nil
		}
		
		self.messageId = messageId
		self.destination = jsonDictionary[MMAPIKeys.kMODestination] as? String
		self.text = text
		self.status = MOMessageSentStatus(rawValue: status) ?? MOMessageSentStatus.Undefined
		self.customPayload = jsonDictionary[MMAPIKeys.kMOCustomPayload] as? [String: CustomPayloadSupportedTypes]
	}
}