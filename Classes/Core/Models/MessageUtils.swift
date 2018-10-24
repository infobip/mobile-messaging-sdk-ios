//
//  MMMessage.swift
//
//  Created by Andrey K. on 15/07/16.
//
//

import Foundation

@objc public enum MessageDeliveryMethod: Int16 {
	case undefined = 0, push, pull, generatedLocally, local
}

@objc public enum MessageDirection: Int16 {
	case MT = 0, MO
}

public typealias APNSPayload = [AnyHashable: Any]
public typealias StringKeyPayload = [String: Any]

public enum PushPayloadAPS {
	case SilentAPS(APNSPayload)
	case NativeAPS(APNSPayload)
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
			let alert = dict["alert"] as? APNSPayload
			return alert?["body"] as? String
		case .SilentAPS(let dict):
			let alert = dict["alert"] as? APNSPayload
			return alert?["body"] as? String
		case .undefined:
			return nil
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
		case .undefined:
			return nil
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
		case .undefined:
			return nil
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
		case .undefined:
			return nil
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
		case .undefined:
			return nil
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

func ==(lhs: MTMessage, rhs: MTMessage) -> Bool {
	return lhs.messageId == rhs.messageId
}

@objc public enum MOMessageSentStatus : Int16 {
	case Undefined = -1
	case SentSuccessfully = 0
	case SentWithFailure = 1
}

@objc public protocol CustomPayloadSupportedTypes {}
extension NSString: CustomPayloadSupportedTypes {}
extension NSNull: CustomPayloadSupportedTypes {}
extension NSNumber: CustomPayloadSupportedTypes {}

protocol MOMessageAttributes {
	var destination: String? {get}
	var text: String {get}
	var customPayload: StringKeyPayload? {get}
	var messageId: String {get}
	var sentStatus: MOMessageSentStatus {get}
    var bulkId: String? {get}
    var initialMessageId: String? {get}
}

struct MOAttributes: MOMessageAttributes {
	let destination: String?
	let text: String
	let customPayload: StringKeyPayload?
	let messageId: String
	let sentStatus: MOMessageSentStatus
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

func apsByMerging(nativeAPS: StringKeyPayload?, withSilentAPS silentAPS: StringKeyPayload) -> StringKeyPayload {
	var resultAps = nativeAPS ?? StringKeyPayload()
	var alert = StringKeyPayload()
	
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

