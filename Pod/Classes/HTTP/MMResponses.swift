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
typealias MMSeenMessagesResult = Result<MMHTTPSeenMessagesResponse>
typealias MMUserDataSyncResult = Result<MMHTTPUserDataSyncResponse>
typealias MMMOMessageResult = Result<MMHTTPMOMessageResponse>

extension NSDate: JSONEncodable {
	public func toJSON() -> Freddy.JSON {
		return NSDateStaticFormatters.ContactsServiceDateFormatter.stringFromDate(self).toJSON()
	}
}

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

class MMHTTPResponse: JSONDecodable {
	required init(json value: JSON) throws {
	}
}

//MARK: API Responses
final class MMHTTPRegistrationResponse: MMHTTPResponse {
    let internalUserId: String

	required init(json value: JSON) throws {
		self.internalUserId = try value.string(MMAPIKeys.kInternalRegistrationId)
		try super.init(json: value)
	}
}

class MMHTTPEmptyResponse: MMHTTPResponse {
}

class TESTC {
	let name: String?
	init(name: String? ){
		self.name = nil
	}
}

final class MMHTTPDeliveryReportingResponse: MMHTTPEmptyResponse { }
final class MMHTTPUserDataUpdateResponse: MMHTTPEmptyResponse { }
final class MMHTTPSeenMessagesResponse: MMHTTPEmptyResponse { }
final class MMHTTPSyncMessagesResponse: MMHTTPResponse {
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
final class MMHTTPUserDataSyncResponse: MMHTTPResponse {
	typealias ErrorMessage = String
	typealias AttributeName = String
	typealias ValueType = AnyObject
	
	let predefinedData: [AttributeName: ValueType]?
	let customData: [AttributeName: ValueType]?
	let error: MMRequestError? //TODO: UserData v2 negotiate the errors format.
	
	required init(json value: JSON) throws {
		if let predefinedDataJSON = try? value.dictionary(MMAPIKeys.kUserDataPredefinedUserData) {
			self.predefinedData = jsonDictToNormalDict(predefinedDataJSON)
		} else {
			self.predefinedData = nil
		}
		
		if let customDataJSON = try? value.dictionary(MMAPIKeys.kUserDataCustomUserData) {
			self.customData = jsonDictToNormalDict(customDataJSON)
		} else {
			self.customData = nil
		}
		
		self.error = try? MMRequestError(json: value)
		
		try super.init(json: value)
	}
}
final class MMHTTPMOMessageResponse: MMHTTPResponse {
	let messages: [MOMessage]
	
	required init(json value: JSON) throws {
		if let messageJSONs = try? value.array(MMAPIKeys.kMOMessages) {
			
			self.messages = try messageJSONs.map({ (messageJSON) -> MOMessage in
				return try MOMessage(json: messageJSON)
			})

		} else {
			throw JSON.Error.KeyNotFound(key: MMAPIKeys.kMOMessages)
		}
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