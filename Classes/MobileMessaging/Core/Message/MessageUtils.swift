//
//  MMMessage.swift
//
//  Created by Andrey K. on 15/07/16.
//
//

import Foundation

@objc public enum MMMessageDeliveryMethod: Int16 {
	case undefined = 0, push, pull, generatedLocally, local
}

@objc public enum MMMessageDirection: Int16 {
	case MT = 0, MO
}

public typealias MMAPNSPayload = [AnyHashable: Any]
public typealias MMStringKeyPayload = [String: Any]

public enum MMPushPayloadAPS {
	case SilentAPS(MMAPNSPayload)
	case NativeAPS(MMAPNSPayload)
	case undefined
	
	var badge: Int? {
		switch self {
		case .NativeAPS(let dict):
			return dict["badge"] as? Int
		case .SilentAPS(let dict):
			return dict["badge"] as? Int
		case .undefined:
			return nil
		}
	}
	
	var sound: String? {
		switch self {
		case .NativeAPS(let dict):
			return dict["sound"] as? String
		case .SilentAPS(let dict):
			return dict["sound"] as? String
		case .undefined:
			return nil
		}
	}
	
	var text: String? {
		switch self {
		case .NativeAPS(let dict):
			let alert = dict["alert"] as? MMAPNSPayload
			return alert?["body"] as? String
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? MMAPNSPayload
			return alert?["body"] as? String
		case .undefined:
			return nil
		}
	}
	
	var title: String? {
		switch self {
		case .NativeAPS(let dict):
			let alert = dict["alert"] as? MMAPNSPayload
			return alert?["title"] as? String
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? MMAPNSPayload
			return alert?["title"] as? String
		case .undefined:
			return nil
		}
	}
	
	var loc_key: String? {
		switch self {
		case .NativeAPS(let dict):
			let alert = dict["alert"] as? MMAPNSPayload
			return alert?["loc-key"] as? String
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? MMAPNSPayload
			return alert?["loc-key"] as? String
		case .undefined:
			return nil
		}
	}
	
	var loc_args: [String]? {
		switch self {
		case .NativeAPS(let dict):
			let alert = dict["alert"] as? MMAPNSPayload
			return alert?["loc-args"] as? [String]
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? MMAPNSPayload
			return alert?["loc-args"] as? [String]
		case .undefined:
			return nil
		}
	}
	
	var title_loc_key: String? {
		switch self {
		case .NativeAPS(let dict):
			let alert = dict["alert"] as? MMAPNSPayload
			return alert?["title-loc-key"] as? String
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? MMAPNSPayload
			return alert?["title-loc-key"] as? String
		case .undefined:
			return nil
		}
	}
	
	var title_loc_args: [String]? {
		switch self {
		case .NativeAPS(let dict):
			let alert = dict["alert"] as? MMAPNSPayload
			return alert?["title-loc-args"] as? [String]
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? MMAPNSPayload
			return alert?["title-loc-args"] as? [String]
		case .undefined:
			return nil
		}
	}
	
	var category: String? {
		switch self {
		case .NativeAPS(let dict):
			return dict["category"] as? String
		case .SilentAPS(let dict):
			return dict["category"] as? String
		case .undefined:
			return nil
		}
	}
}

protocol MMMessageMetadata: Hashable {
	var isSilent: Bool {get}
	var messageId: String {get}
}

func ==(lhs: MM_MTMessage, rhs: MM_MTMessage) -> Bool {
	return lhs.messageId == rhs.messageId
}

@objc public enum MM_MOMessageSentStatus : Int16 {
	case Undefined = -1
	case SentSuccessfully = 0
	case SentWithFailure = 1
}

@objc public protocol MMCustomPayloadSupportedTypes {}
extension NSString: MMCustomPayloadSupportedTypes {}
extension NSNull: MMCustomPayloadSupportedTypes {}
extension NSNumber: MMCustomPayloadSupportedTypes {}

protocol MOMessageAttributes {
	var destination: String? {get}
	var text: String {get}
	var customPayload: MMStringKeyPayload? {get}
	var messageId: String {get}
	var sentStatus: MM_MOMessageSentStatus {get}
    var bulkId: String? {get}
    var initialMessageId: String? {get}
}

struct MOAttributes: MOMessageAttributes {
	let destination: String?
	let text: String
	let customPayload: MMStringKeyPayload?
	let messageId: String
	let sentStatus: MM_MOMessageSentStatus
    let bulkId: String?
    let initialMessageId: String?
	
	var dictRepresentation: DictionaryRepresentation {
		var result = DictionaryRepresentation()
		result[Consts.APIKeys.MO.destination] = destination
		result[Consts.APIKeys.MO.text] = text
		result[Consts.APIKeys.MO.customPayload] = customPayload
		result[Consts.APIKeys.MO.messageId] = messageId
		result[Consts.APIKeys.MO.messageSentStatusCode] = NSNumber(value: sentStatus.rawValue)
        result[Consts.APIKeys.MO.bulkId] = bulkId
        result[Consts.APIKeys.MO.initialMessageId] = initialMessageId
		return result
	}
}

public func apsByMerging(nativeAPS: MMStringKeyPayload?, withSilentAPS silentAPS: MMStringKeyPayload) -> MMStringKeyPayload {
	var resultAps = nativeAPS ?? MMStringKeyPayload()
	var alert = MMStringKeyPayload()
	
	if let body = silentAPS[Consts.APNSPayloadKeys.body] as? String {
		alert[Consts.APNSPayloadKeys.body] = body
	}
	if let title = silentAPS[Consts.APNSPayloadKeys.title] as? String {
		alert[Consts.APNSPayloadKeys.title] = title
	}
	
	resultAps[Consts.APNSPayloadKeys.alert] = alert
	
	if let sound = silentAPS[Consts.APNSPayloadKeys.sound] as? String {
		resultAps[Consts.APNSPayloadKeys.sound] = sound
	}
	return resultAps
}

