//
//  MMResponses.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//  
//

import SwiftyJSON

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

extension NSDate: JSONEncodable {
	public func toJSON() -> JSON {
		return JSON(NSDateStaticFormatters.ContactsServiceDateFormatter.stringFromDate(self))
	}
}

extension JSON {
	
	/// An enum to encapsulate errors that may arise in working with `JSON`.
	public enum Error: ErrorType {
		/// The `index` is out of bounds for a JSON array
		case IndexOutOfBounds(index: Swift.Int)
		
		/// The `key` was not found in the JSON dictionary
		case KeyNotFound(key: Swift.String)

		/// Unexpected JSON `value` was found that is not convertible `to` type
		case ValueNotConvertible(value: JSON, to: Any.Type)
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

final class MMHTTPUserDataUpdateResponse: MMHTTPEmptyResponse { }
final class MMHTTPSeenMessagesResponse: MMHTTPEmptyResponse { }
final class MMHTTPSyncMessagesResponse: MMHTTPResponse {
    let messages : [MMMessage]?
	required init?(json value: JSON) {
		self.messages = value[MMAPIKeys.kPayloads].arrayValue.flatMap { MMMessageFactory.makeMessage($0) }
		super.init(json: value)
	}
}

final class MMHTTPSystemDataSyncResponse: MMHTTPEmptyResponse { }

final class MMHTTPUserDataSyncResponse: MMHTTPResponse {
	typealias ErrorMessage = String
	typealias AttributeName = String
	typealias ValueType = AnyObject
	
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
func ==(lhs: MMMessage, rhs: MMMessage) -> Bool {
	return lhs.messageId == rhs.messageId
}

protocol MMMessageMetadata: Hashable {
	var isSilent: Bool {get}
	var messageId: String {get}
}