//
//  MMResponses.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//  
//

//MARK: - Responses
struct EmptyResponse { }

typealias PutInstanceResponse = EmptyResponse

typealias SeenStatusSendingResponse = EmptyResponse

typealias SystemDataSyncResponse = EmptyResponse

typealias LogoutResponse = EmptyResponse

struct GetInstanceResponse {
	let primary: Bool
}

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
typealias GetInstanceResult = Result<GetInstanceResponse>
typealias PutInstanceResult = Result<PutInstanceResponse>
typealias RegistrationResult = Result<RegistrationResponse>
typealias MessagesSyncResult = Result<MessagesSyncResponse>
typealias SeenStatusSendingResult = Result<SeenStatusSendingResponse>
typealias UserDataSyncResult = Result<UserDataSyncResponse>
typealias SystemDataSyncResult = Result<SystemDataSyncResponse>
typealias LogoutResult = Result<LogoutResponse>
typealias MOMessageSendingResult = Result<MOMessageSendingResponse>
typealias LibraryVersionResult = Result<LibraryVersionResponse>
typealias MMGeoEventReportingResult = Result<GeoEventReportingResponse>

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
		print("")
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

extension GetInstanceResponse: JSONDecodable {
	init?(json value: JSON) {
		self.primary = value["primary"].boolValue
	}
}

extension RegistrationResponse: JSONDecodable {
	init?(json value: JSON) {
		guard let internalId = value[Consts.PushRegistration.internalId].string
			else
		{
			return nil
		}
		
		self.internalId = internalId
		self.isEnabled = value[Consts.PushRegistration.isEnabled].bool ?? true
		self.platform = value[Consts.PushRegistration.platform].string ?? "APNS"
		self.deviceToken = value[Consts.PushRegistration.deviceToken].string ?? "stub"
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

extension UserDataSyncResponse: JSONDecodable {
	init?(json value: JSON) {
		self.predefinedData = value[Consts.APIKeys.UserData.predefinedUserData].dictionaryObject
		self.customData = value[Consts.APIKeys.UserData.customUserData].dictionaryObject?.reduce([CustomUserData](), { (result, pair) -> [CustomUserData] in
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
		self.messages = value[Consts.APIKeys.MO.messages].arrayValue.compactMap({MOMessage.init(moResponseJson: $0)})
	}
}
