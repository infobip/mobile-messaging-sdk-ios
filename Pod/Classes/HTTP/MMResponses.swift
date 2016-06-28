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


public struct MMMessage: Hashable, JSONDecodable {
	
	public var hashValue: Int { return messageId.hashValue }
	let isSilent: Bool
	let messageId: String
	var payload: [String: AnyObject]?
	
	public init(json: JSON) throws {
        var result = [String: AnyObject]()
		self.messageId = try json.string(MMAPIKeys.kMessageId)
		result[MMAPIKeys.kMessageId] = self.messageId
        var aps = [NSObject: AnyObject]()
        if let sound = try? json[MMAPIKeys.kSound]?.string() {
            aps[MMAPIKeys.kSound] = sound
		}
		
		if let ca = try? json[MMAPIKeys.kContentAvailable]?.int() {
			aps[MMAPIKeys.kContentAvailable] = ca
		}
		
        if let badge = try? json[MMAPIKeys.kBadge]?.int() {
            aps[MMAPIKeys.kBadge] = badge
        }
		
        if let value = json[MMAPIKeys.kBody], let body = try? value.string() {
            var alert = [NSObject: AnyObject]()
            alert[MMAPIKeys.kBody] = body
            aps[MMAPIKeys.kAlert] = alert
		}
		
		if aps.count > 0 {
			result[MMAPIKeys.kAps] = aps
        }
		
        self.isSilent = MMMessage.checkIfSilent(result)
        if let data = try? json.dictionary(MMAPIKeys.kGatewayData) {
			result += jsonDictToNormalDict(data)
        }
		self.payload = result
	}
	
	init?(payload: [NSObject: AnyObject]) {
		guard let messageId = payload[MMAPIKeys.kMessageId] as? String,
            let payload = payload as? [String: AnyObject] else {
			return nil
		}
		self.messageId = messageId
		self.payload = payload
		self.isSilent = MMMessage.checkIfSilent(payload)
	}
	
	init(message: MessageManagedObject) {
		self.messageId = message.messageId
		self.isSilent = message.isSilent.boolValue
	}
	
	static func checkIfSilent(payload: [String: AnyObject]) -> Bool {
		guard let aps = payload[MMAPIKeys.kAps] as? [String: AnyObject] else {
			return false
		}
		if aps[MMAPIKeys.kContentAvailable] as? Int != 1 {
			return false
		}
		
		if aps.keys.contains(MMAPIKeys.kAlert) {
			return false
		}
		
		if !aps.keys.contains(MMAPIKeys.kSound) || (aps[MMAPIKeys.kSound] as? String)?.characters.count > 0 { // { sound: "", ...} <- means silent
			return false
		}
		return true
	}
}

