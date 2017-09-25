//
//  MMResponses.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//  
//

//MARK: - Responses
struct EmptyResponse { }

typealias SeenStatusSendingResponse = EmptyResponse

typealias SystemDataSyncResponse = EmptyResponse

struct RegistrationResponse {
	let internalId: String
	let isEnabled: Bool
	let platform: String
	let deviceToken: String
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

struct UserDataSyncResponse {
	let predefinedData: [String: Any]?
	let customData: [CustomUserData]?
	let error: RequestError?
}

struct MOMessageSendingResponse {
	let messages: [MOMessage]
}

typealias DeliveryReportResponse = EmptyResponse

//MARK: - Request results
typealias RegistrationResult = Result<RegistrationResponse>
typealias MessagesSyncResult = Result<MessagesSyncResponse>
typealias SeenStatusSendingResult = Result<SeenStatusSendingResponse>
typealias UserDataSyncResult = Result<UserDataSyncResponse>
typealias SystemDataSyncResult = Result<SystemDataSyncResponse>
typealias MOMessageSendingResult = Result<MOMessageSendingResponse>
typealias LibraryVersionResult = Result<LibraryVersionResponse>
typealias MMGeoEventReportingResult = Result<GeoEventReportingResponse>

public struct RequestError {
	public let messageId: String
	
	public let text: String
	
	var foundationError: NSError {
		var userInfo = [AnyHashable: Any]()
		userInfo[NSLocalizedDescriptionKey] = text
		userInfo[APIKeys.kErrorText] = text
		userInfo[APIKeys.kErrorMessageId] = messageId
		return NSError(domain: APIKeys.kBackendErrorDomain, code: Int(messageId) ?? 0, userInfo: userInfo)
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
	init?(json value: JSON) { }
}

extension Date: JSONEncodable {
	func toJSON() -> JSON {
		return JSON(DateStaticFormatters.ContactsServiceDateFormatter.string(from: self))
	}
}

extension RequestError: JSONDecodable {
	init?(json value: JSON) {
		let serviceException = value[APIKeys.kRequestError][APIKeys.kServiceException]
		guard
			let text = serviceException[APIKeys.kErrorText].string,
			let messageId = serviceException[APIKeys.kErrorMessageId].string
		else {
			return nil
		}
		
		self.messageId = messageId
		self.text = text
	}
}

extension RegistrationResponse: JSONDecodable {
	init?(json value: JSON) {
		guard let internalId = value[PushRegistration.internalId].string
			else
		{
			return nil
		}
		
		self.internalId = internalId
		self.isEnabled = value[PushRegistration.isEnabled].bool ?? true
		self.platform = value[PushRegistration.platform].string ?? "APNS"
		self.deviceToken = value[PushRegistration.deviceToken].string ?? "stub"
	}
}

extension GeoEventReportingResponse: JSONDecodable {
	init?(json value: JSON) {
		guard let tempMessageIdRealMessageId = value[GeoReportingAPIKeys.messageIdsMap].dictionaryObject as? [String: String] else {
			return nil
		}
		self.tempMessageIdRealMessageId = tempMessageIdRealMessageId
		self.finishedCampaignIds = value[GeoReportingAPIKeys.finishedCampaignIds].arrayObject as? [String]
		self.suspendedCampaignIds = value[GeoReportingAPIKeys.suspendedCampaignIds].arrayObject as? [String]
	}
}

extension LibraryVersionResponse: JSONDecodable {
	init?(json value: JSON) {
		guard let platformType = value[VersionCheck.platformType].rawString(),
			let libraryVersion = value[VersionCheck.libraryVersion].rawString(),
			let updateUrl = value[VersionCheck.libraryVersionUpdateUrl].rawString() else {
				return nil
		}
		self.platformType = platformType
		self.libraryVersion = libraryVersion
		self.updateUrl = updateUrl
	}
}

extension MessagesSyncResponse: JSONDecodable{
	init?(json value: JSON) {
		self.messages = value[APNSPayloadKeys.payloads].arrayValue.flatMap { MTMessage(json: $0) }
	}
}

extension UserDataSyncResponse: JSONDecodable {
	init?(json value: JSON) {
		self.predefinedData = value[APIKeys.kUserDataPredefinedUserData].dictionaryObject
		self.customData = value[APIKeys.kUserDataCustomUserData].dictionaryObject?.reduce([CustomUserData](), { (result, pair) -> [CustomUserData] in
			if let element = CustomUserData(dictRepresentation: [pair.0: pair.1]) {
				return result + [element]
			} else {
				return result
			}
		})
		self.error = RequestError(json: value)
	}
}

extension MOMessageSendingResponse: JSONDecodable {
	init?(json value: JSON) {
		self.messages = value[APIKeys.kMOMessages].arrayValue.flatMap(MOMessage.init)
	}
}
