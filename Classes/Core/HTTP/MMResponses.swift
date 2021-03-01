//
//  MMResponses.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//  
//

enum MMResult<ValueType> {
	case Success(ValueType)
	case Failure(NSError?)
	case Cancel

	var value: ValueType? {
		switch self {
		case .Success(let value):
			return value
		case .Failure, .Cancel:
			return nil
		}
	}

	var error: NSError? {
		switch self {
		case .Success, .Cancel:
			return nil
		case .Failure(let error):
			return error
		}
	}
}


struct EmptyResponse { }

struct BaseUrlResponse {
    let baseUrl: String
}

struct GeoEventReportingResponse {
	let finishedCampaignIds: [String]?
	let suspendedCampaignIds: [String]?
	let tempMessageIdRealMessageId: [String: String]
}

struct LibraryVersionResponse {
	let platformType : String
	let libraryVersion : String
	let updateUrl : String
}

struct MessagesSyncResponse {
	let messages: [MTMessage]?
}

struct MOMessageSendingResponse {
	let messages: [MOMessage]
}

//MARK: - Request results
typealias MessagesSyncResult = MMResult<MessagesSyncResponse>
typealias SeenStatusSendingResult = MMResult<EmptyResponse>
typealias UserSessionSendingResult = MMResult<EmptyResponse>
typealias CustomEventResult = MMResult<EmptyResponse>
typealias DepersonalizeResult = MMResult<EmptyResponse>
typealias MOMessageSendingResult = MMResult<MOMessageSendingResponse>
typealias LibraryVersionResult = MMResult<LibraryVersionResponse>
typealias BaseUrlResult = MMResult<BaseUrlResponse>
typealias GeoEventReportingResult = MMResult<GeoEventReportingResponse>
typealias FetchUserDataResult = MMResult<User>
typealias UpdateUserDataResult = MMResult<EmptyResponse>
typealias FetchInstanceDataResult = MMResult<Installation>
typealias UpdateInstanceDataResult = MMResult<EmptyResponse>
typealias PersonalizeResult = MMResult<User>
typealias DeliveryReportResult = MMResult<EmptyResponse>

public struct RequestError {
	public let messageId: String
	
	public let text: String
	
	var foundationError: NSError {
		var userInfo = [String: Any]()
		userInfo[NSLocalizedDescriptionKey] = text
		userInfo[Consts.APIKeys.errorText] = text
		userInfo[Consts.APIKeys.errorMessageId] = messageId
		return NSError(domain: Consts.APIKeys.backendErrorDomain, code: Int(messageId) ?? 0, userInfo: userInfo)
	}
}

//MARK: - JSON encoding/decoding
protocol JSONDecodable {
	init?(json: JSON)
}

protocol JSONEncodable {
	func toJSON() -> JSON
}

extension EmptyResponse: JSONDecodable {
	init?(json value: JSON) {
	}
}

extension RequestError: JSONDecodable {
	init?(json value: JSON) {
		let serviceException = value[Consts.APIKeys.requestError][Consts.APIKeys.serviceException]
		guard
			let text = serviceException[Consts.APIKeys.errorText].string,
			let messageId = serviceException[Consts.APIKeys.errorMessageId].string
			else {
				return nil
		}
		
		self.messageId = messageId
		self.text = text
	}
}

extension GeoEventReportingResponse: JSONDecodable {
	init?(json value: JSON) {
		guard let tempMessageIdRealMessageId = value[Consts.GeoReportingAPIKeys.messageIdsMap].dictionaryObject as? [String: String] else {
			return nil
		}
		self.tempMessageIdRealMessageId = tempMessageIdRealMessageId
		self.finishedCampaignIds = value[Consts.GeoReportingAPIKeys.finishedCampaignIds].arrayObject as? [String]
		self.suspendedCampaignIds = value[Consts.GeoReportingAPIKeys.suspendedCampaignIds].arrayObject as? [String]
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
        guard let baseUrl = value[Consts.BaseUrlRecovery.baseUrl].rawString() else {
            return nil
        }
        self.baseUrl = baseUrl
    }
}

extension MessagesSyncResponse: JSONDecodable{
	init?(json value: JSON) {
		self.messages = value[Consts.APNSPayloadKeys.payloads].arrayValue.compactMap { MTMessage(messageSyncResponseJson: $0) }
	}
}

extension Substring  {
	var isNumber: Bool {
		return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
	}
}

extension MOMessageSendingResponse: JSONDecodable {
	init?(json value: JSON) {
		self.messages = value[Consts.APIKeys.MO.messages].arrayValue.compactMap({MOMessage.init(moResponseJson: $0)})
	}
}
