//
//  MMResponses.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//  
//

//import SwiftyJSON

typealias MMRegistrationResult = Result<MMHTTPRegistrationResponse>
typealias MMFetchMessagesResult = Result<MMHTTPSyncMessagesResponse>
typealias MMSeenMessagesResult = Result<MMHTTPSeenMessagesResponse>
typealias MMUserDataSyncResult = Result<MMHTTPUserDataSyncResponse>
typealias MMSystemDataSyncResult = Result<MMHTTPSystemDataSyncResponse>
typealias MMMOMessageResult = Result<MMHTTPMOMessageResponse>

public protocol JSONDecodable {
	init?(json: JSON)
}
public protocol JSONEncodable {
	func toJSON() -> JSON
}

extension Date: JSONEncodable {
	public func toJSON() -> JSON {
		return JSON(DateStaticFormatters.ContactsServiceDateFormatter.string(from: self))
	}
}

public struct MMRequestError {
	public var isUNAUTHORIZED: Bool {
		return messageId == "UNAUTHORIZED"
	}
	
	public let messageId: String
	
	public let text: String
	
	var foundationError: NSError {
		var userInfo = [AnyHashable: Any]()
		userInfo[NSLocalizedDescriptionKey] = text
		userInfo[MMAPIKeys.kErrorText] = text
		userInfo[MMAPIKeys.kErrorMessageId] = messageId
		return NSError(domain: MMAPIKeys.kBackendErrorDomain, code: Int(messageId) ?? 0, userInfo: userInfo)
	}
}

extension MMRequestError: JSONDecodable {
	public init?(json value: JSON) {
		let serviceException = value[MMAPIKeys.kRequestError][MMAPIKeys.kServiceException]
		guard
			let text = serviceException[MMAPIKeys.kErrorText].string,
			let messageId = serviceException[MMAPIKeys.kErrorMessageId].string
		else {
			return nil
		}
		
		self.messageId = messageId
		self.text = text
	}
}

class MMHTTPResponse: JSONDecodable {
	required init?(json value: JSON) {
	}
}

//MARK: API Responses
final class MMHTTPRegistrationResponse: MMHTTPResponse {
    let internalUserId: String

	required init?(json value: JSON) {
		if let internalUserId = value[MMAPIKeys.kInternalRegistrationId].string {
			self.internalUserId = internalUserId
		} else {
			return nil
		}
		super.init(json: value)
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

final class MMHTTPUserDataUpdateResponse: MMHTTPEmptyResponse { }
final class MMHTTPSeenMessagesResponse: MMHTTPEmptyResponse { }
final class MMHTTPSyncMessagesResponse: MMHTTPResponse {
    let messages : [MMMessage]?
	required init?(json value: JSON) {
		self.messages = value[MMAPIKeys.kPayloads].arrayValue.flatMap { MMMessage(json: $0) }
		super.init(json: value)
	}
}

final class MMHTTPSystemDataSyncResponse: MMHTTPEmptyResponse { }

final class MMHTTPUserDataSyncResponse: MMHTTPResponse {
	typealias ErrorMessage = String
	typealias AttributeName = String
	typealias ValueType = Any
	
	let predefinedData: [AttributeName: ValueType]?
	let customData: [AttributeName: ValueType]?
	let error: MMRequestError? //TODO: UserData v2 negotiate the errors format.
	
	required init?(json value: JSON) {
		self.predefinedData = value[MMAPIKeys.kUserDataPredefinedUserData].dictionaryObject
		self.customData = value[MMAPIKeys.kUserDataCustomUserData].dictionaryObject
		self.error = MMRequestError(json: value)
		super.init(json: value)
	}
}
final class MMHTTPMOMessageResponse: MMHTTPResponse {
	let messages: [MOMessage]
	
	required init?(json value: JSON) {
		self.messages = value[MMAPIKeys.kMOMessages].arrayValue.flatMap(MOMessage.init)
		super.init(json: value)
	}
}


//MARK: Other
public func ==(lhs: MMMessage, rhs: MMMessage) -> Bool {
	return lhs.messageId == rhs.messageId
}

protocol MMMessageMetadata: Hashable {
	var isSilent: Bool {get}
	var messageId: String {get}
}

enum MMAPS {
	case SilentAPS([AnyHashable: Any])
	case NativeAPS([AnyHashable: Any])
	
	var text: String? {
		switch self {
		case .NativeAPS(let dict):
			return (dict["alert"] as? [AnyHashable: Any])?["body"] as? String
		case .SilentAPS(let dict):
			return (dict["alert"] as? [AnyHashable: Any])?["body"] as? String
		}
	}
}
