// 
//  MMResponses.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation

public enum MMResult<ValueType> {
	case Success(ValueType)
	case Failure(NSError?)
	case Cancel

	public var value: ValueType? {
		switch self {
		case .Success(let value):
			return value
		case .Failure, .Cancel:
			return nil
		}
	}

    public var error: NSError? {
		switch self {
		case .Success, .Cancel:
			return nil
		case .Failure(let error):
			return error
		}
	}
}


public struct EmptyResponse { }

struct BaseUrlResponse {
    let baseUrl: String?
}

struct LibraryVersionResponse {
	let platformType : String
	let libraryVersion : String
	let updateUrl : String
}

struct MessagesSyncResponse {
	let messages: [MM_MTMessage]?
}

struct MOMessageSendingResponse {
	let messages: [MM_MOMessage]
}

//MARK: - Request results
typealias MessagesSyncResult = MMResult<MessagesSyncResponse>
public typealias SeenStatusSendingResult = MMResult<EmptyResponse>
typealias UserSessionSendingResult = MMResult<EmptyResponse>
typealias CustomEventResult = MMResult<EmptyResponse>
typealias DepersonalizeResult = MMResult<EmptyResponse>
typealias MOMessageSendingResult = MMResult<MOMessageSendingResponse>
typealias LibraryVersionResult = MMResult<LibraryVersionResponse>
typealias BaseUrlResult = MMResult<BaseUrlResponse>
typealias FetchUserDataResult = MMResult<MMUser>
typealias UpdateUserDataResult = MMResult<EmptyResponse>
typealias FetchInstanceDataResult = MMResult<MMInstallation>
typealias UpdateInstanceDataResult = MMResult<EmptyResponse>
typealias PersonalizeResult = MMResult<MMUser>
typealias DeliveryReportResult = MMResult<EmptyResponse>
typealias WebInAppClickReportResult = MMResult<EmptyResponse>

public struct MMRequestError {
	public let messageId: String
	
	public let text: String
	
	var foundationError: NSError {
		return foundationError(httpStatusCode: nil)
	}

	func foundationError(httpStatusCode: Int?) -> NSError {
		var userInfo = [String: Any]()
		userInfo[NSLocalizedDescriptionKey] = text
		userInfo[Consts.APIKeys.errorText] = text
		userInfo[Consts.APIKeys.errorMessageId] = messageId
		userInfo[Consts.APIKeys.errorHttpStatusCode] = httpStatusCode
		return NSError(domain: Consts.APIKeys.backendErrorDomain, code: Int(messageId) ?? 0, userInfo: userInfo)
	}
}

//MARK: - JSON encoding/decoding
public protocol JSONDecodable {
	init?(json: JSON)
}

public protocol JSONEncodable {
	func toJSON() -> JSON
}

extension EmptyResponse: JSONDecodable {
    public init?(json value: JSON) {
	}
}

extension MMRequestError: JSONDecodable {
    public init?(json value: JSON) {
		let serviceException = value[Consts.APIKeys.requestError][Consts.APIKeys.serviceException]
		// The error code is what callers branch on, so it is required; a missing text falls back to the code.
		guard let messageId = MMRequestError.nonBlank(serviceException[Consts.APIKeys.errorMessageId].string) else {
			return nil
		}
		
		self.messageId = messageId
		self.text = MMRequestError.nonBlank(serviceException[Consts.APIKeys.errorText].string) ?? messageId
	}

	/// Server error text of a body that has no usable error code, so it can still be reported with the HTTP status.
	static func text(fromErrorBody value: JSON) -> String? {
		return nonBlank(value[Consts.APIKeys.requestError][Consts.APIKeys.serviceException][Consts.APIKeys.errorText].string)
	}

	private static func nonBlank(_ string: String?) -> String? {
		guard let string = string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			return nil
		}
		return string
	}
}

extension LibraryVersionResponse: JSONDecodable {
	init?(json value: JSON) {
		guard let platformType = value[Consts.VersionCheck.platformType].rawString(),
			let libraryVersion = value[Consts.VersionCheck.libraryVersion].rawString(),
			let updateUrl = value[Consts.VersionCheck.libraryVersionUpdateUrl].rawString() else {
				return nil
		}
		self.platformType = platformType
		self.libraryVersion = libraryVersion
		self.updateUrl = updateUrl
	}
}

extension BaseUrlResponse: JSONDecodable {
    init?(json value: JSON) {
        self.baseUrl = value[Consts.BaseUrlRecovery.baseUrl].string
    }
}

extension MessagesSyncResponse: JSONDecodable{
	init?(json value: JSON) {
		self.messages = value[Consts.APNSPayloadKeys.payloads].arrayValue.compactMap { MM_MTMessage(messageSyncResponseJson: $0) }
	}
}

extension Substring  {
	var isNumber: Bool {
		return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
	}
}

extension MOMessageSendingResponse: JSONDecodable {
	init?(json value: JSON) {
		self.messages = value[Consts.APIKeys.MO.messages].arrayValue.compactMap({MM_MOMessage.init(moResponseJson: $0)})
	}
}
