//
//  MMResponses.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//  
//

import Freddy

typealias MMRegistrationResult = Result<MMHTTPRegistrationResponse>
typealias MMDeliveryReportingResult = Result<MMHTTPDeliveryReportingResponse>
typealias MMFetchMessagesResult = Result<MMHTTPSyncMessagesResponse>
typealias MMSaveEmailResult = Result<MMHTTPSaveEmailResponse>
typealias MMSaveMSISDNResult = Result<MMHTTPSaveMSISDNResponse>
typealias MMSeenMessagesResult = Result<MMHTTPSeenMessagesResponse>

public struct MMRequestError {
	public var isUNAUTHORIZED: Bool {
		return messageId == "UNAUTHORIZED"
	}
	
	public let messageId: String
	
	public let text: String
	
	var foundationError: NSError {
		var userInfo = [NSObject: AnyObject]()
		userInfo[NSLocalizedDescriptionKey] = text
		userInfo[MMAPIKeys.kErrorText] = text
		userInfo[MMAPIKeys.kErrorMessageId] = messageId
		return NSError(domain: MMAPIKeys.kBackendErrorDomain, code: Int(messageId) ?? 0, userInfo: userInfo)
	}
}

extension MMRequestError: JSONDecodable {
	public init(json value: JSON) throws {
		let requestError = try value.dictionary(MMAPIKeys.kRequestError)
		guard
			let serviceException = requestError[MMAPIKeys.kServiceException],
			let text = try? serviceException.string(MMAPIKeys.kErrorText),
			let messageId = try? serviceException.string(MMAPIKeys.kErrorMessageId)
		else {
			throw JSON.Error.ValueNotConvertible(value: value, to: self.dynamicType)
		}
		
		self.messageId = messageId
		self.text = text
	}
}

class MMHTTPResponse : JSONDecodable {
	required init(json value: JSON) throws {
	}
}

//MARK: API Responses
final class MMHTTPRegistrationResponse : MMHTTPResponse {
    let internalId: String

	required init(json value: JSON) throws {
		self.internalId = try value.string(MMAPIKeys.kInternalRegistrationId)
		try super.init(json: value)
	}
}

class MMHTTPEmptyResponse : MMHTTPResponse {
}

final class MMHTTPDeliveryReportingResponse: MMHTTPEmptyResponse { }
final class MMHTTPSaveEmailResponse: MMHTTPEmptyResponse { }
final class MMHTTPSaveMSISDNResponse: MMHTTPEmptyResponse { }
final class MMHTTPSeenMessagesResponse: MMHTTPEmptyResponse { }

final class MMHTTPSyncMessagesResponse : MMHTTPResponse {
    let messages : [MMMessage]?
	required init(json value: JSON) throws {
		var payloads = [JSON]()
		do {
			payloads = try value.array(MMAPIKeys.kPayloads)
		} catch JSON.Error.KeyNotFound(key: MMAPIKeys.kPayloads){
			MMLogDebug("MMHTTPSyncMessagesResponse: nothing to fetch")
		}
		self.messages = try payloads.map {try MMMessage(json: $0)}
		try super.init(json: value)
	}
}

//MARK: Other
public func ==(lhs: MMMessage, rhs: MMMessage) -> Bool {
	return lhs.messageId == rhs.messageId
}

//TODO: reafactor
func jsonDictToNormalDict(jsonDict: [String: JSON]) -> [String: AnyObject] {
	var normalDict = [String : AnyObject]()
	for (key,value) in jsonDict {
		normalDict[key] = jsonToAnyObject(value)
	}
	return normalDict
}

func jsonArrToNormalArr(jsonArr: [JSON]) -> [AnyObject] {
	return jsonArr.flatMap(jsonToAnyObject)
}


func jsonToAnyObject(json: JSON) -> AnyObject {
	switch json {
	case JSON.Array(let jsonArray):
		return jsonArrToNormalArr(jsonArray)
	case JSON.Dictionary(let jsonDictionary):
		return jsonDictToNormalDict(jsonDictionary)
	case .String(let str):
		return str
	case .Double(let num):
		return num
	case .Int(let int):
		return int
	case .Bool(let b):
		return b
	case JSON.Null:
		return NSNull()
	}
}

protocol MMMessageMetadata: Hashable {
	var isSilent: Bool {get}
	var messageId: String {get}
}

enum MMAPS {
	case SilentAPS([String: AnyObject])
	case NativeAPS([String: AnyObject])
}

public struct MMMessage: MMMessageMetadata, JSONDecodable {
	
	public var hashValue: Int { return messageId.hashValue }
	let isSilent: Bool
	let messageId: String
	let originalPayload: [String: AnyObject]
	let customPayload: [String: AnyObject]?
	let aps: MMAPS
	let silentData: [String: AnyObject]?
//	let geoData: [String: AnyObject]? // Future
	let interactionsData: [String: AnyObject]?
	
	public init(json: JSON) throws {
		if let payload = jsonToAnyObject(json) as? [String : AnyObject] {
			try self.init(payload: payload)
		} else {
			throw JSON.Error.ValueNotConvertible(value: json, to: MMMessage.self)
		}
	}
	
	init(payload: [NSObject: AnyObject]) throws {
		guard let messageId = payload[MMAPIKeys.kMessageId] as? String else {
			throw JSON.Error.KeyNotFound(key: MMAPIKeys.kMessageId)
		}
		guard let nativeAPS = payload[MMAPIKeys.kAps] as? [String: AnyObject] else {
			throw JSON.Error.KeyNotFound(key: MMAPIKeys.kAps)
		}
		
		self.messageId = messageId
		self.isSilent = MMMessage.checkIfSilent(payload)
		if (self.isSilent) {
			if let silentAPS = payload[MMAPIKeys.kInternalData]?[MMAPIKeys.kSilent] as? [String: AnyObject] {
				self.aps = MMAPS.SilentAPS(MMMessage.mergeApsWithSilentParameters(nativeAPS, silentAPS: silentAPS))
			} else {
				self.aps = MMAPS.NativeAPS(nativeAPS)
			}
		} else {
			self.aps = MMAPS.NativeAPS(nativeAPS)
		}
		self.originalPayload = payload as! [String: AnyObject]
		self.customPayload = payload[MMAPIKeys.kCustomPayload] as? [String : AnyObject]
		self.silentData = payload[MMAPIKeys.kInternalData]?[MMAPIKeys.kSilent] as? [String : AnyObject]
		self.interactionsData = payload[MMAPIKeys.kInternalData]?[MMAPIKeys.kInteractive] as? [String : AnyObject]
	}
		
	static func checkIfSilent(payload: [NSObject: AnyObject]?) -> Bool {
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
		
		resultAps[MMAPIKeys.kAlert] = alert
		
		if let sound = silentAPS[MMAPIKeys.kSound] as? String {
			resultAps[MMAPIKeys.kSound] = sound
		}
		return resultAps
	}
}

