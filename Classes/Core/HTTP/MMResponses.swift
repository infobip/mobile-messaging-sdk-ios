//
//  MMResponses.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//  
//

struct EmptyResponse { }

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
typealias MessagesSyncResult = Result<MessagesSyncResponse>
typealias SeenStatusSendingResult = Result<EmptyResponse>
typealias DepersonalizeResult = Result<EmptyResponse>
typealias MOMessageSendingResult = Result<MOMessageSendingResponse>
typealias LibraryVersionResult = Result<LibraryVersionResponse>
typealias GeoEventReportingResult = Result<GeoEventReportingResponse>
typealias FetchUserDataResult = Result<User>
typealias UpdateUserDataResult = Result<EmptyResponse>
typealias FetchInstanceDataResult = Result<Installation>
typealias UpdateInstanceDataResult = Result<EmptyResponse>
typealias PersonalizeResult = Result<User>
typealias DeliveryReportResult = Result<EmptyResponse>

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

extension Date: JSONEncodable {
	func toJSON() -> JSON {
		return JSON(DateStaticFormatters.ContactsServiceDateFormatter.string(from: self))
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
