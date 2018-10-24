//
//  MMRequests.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//

enum APIPath: String {
	case Registration = "/mobile/4/registration"
	case SeenMessages = "/mobile/1/messages/seen"
	case SyncMessages = "/mobile/5/messages"
	case UserData = "/mobile/5/data/user"
	case MOMessage = "/mobile/1/messages/mo"
	case SystemData = "/mobile/2/data/system"
	case LibraryVersion = "/mobile/3/version"
	case GeoEventsReports = "/mobile/4/geo/event"
	case DeliveryReport = "/mobile/1/messages/deliveryreport"
	case Logout = "/mobile/1/data/logout"
	case Instance = "/mobile/1/instance"
}

struct PutInstanceRequest: PutRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = PutInstanceResponse
	var path: APIPath { return .Instance }
	
	let isPrimary: Bool
	var body: RequestBody? { return ["primary": isPrimary] }
	
	init(applicationCode: String, pushRegistrationId: String, isPrimary: Bool) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.isPrimary = isPrimary
	}
}

struct GetInstanceRequest: GetRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = GetInstanceResponse
	var path: APIPath { return .Instance }

	init(applicationCode: String, pushRegistrationId: String) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
	}
}

struct RegistrationRequest: PostRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = RegistrationResponse
	var retryLimit: Int { return 3 }
	func mustRetryOnResponseError(_ error: NSError) -> Bool {
		return retryLimit > 0 && error.mm_isRetryable
	}
	var path: APIPath { return .Registration }
	var parameters: RequestParameters? {
		var params: RequestParameters = [Consts.PushRegistration.deviceToken: deviceToken,
										 Consts.PushRegistration.platform: Consts.APIValues.platformType]
		params[Consts.PushRegistration.expiredInternalId] = expiredInternalId
		if let isEnabled = isEnabled {
			params[Consts.PushRegistration.isEnabled] = isEnabled ? 1 : 0
		}
		return params
	}
	let deviceToken: String
	let isEnabled: Bool?
	let expiredInternalId: String?

	init(applicationCode: String, pushRegistrationId: String?, deviceToken: String, isEnabled: Bool?, expiredInternalId: String?) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.deviceToken = deviceToken
		self.isEnabled = isEnabled
		self.expiredInternalId = expiredInternalId
	}
}

struct SeenStatusSendingRequest: PostRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = SeenStatusSendingResponse
	var path: APIPath { return .SeenMessages }

	let seenList: [SeenData]
	var body: RequestBody? { return SeenData.requestBody(seenList: seenList) }

	init(applicationCode: String, pushRegistrationId: String?, seenList: [SeenData]) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.seenList = seenList
	}
}

struct LibraryVersionRequest: GetRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = LibraryVersionResponse
	var path: APIPath { return .LibraryVersion }
	var parameters: [String: Any]? = [Consts.PushRegistration.platform: Consts.APIValues.platformType]

	init(applicationCode: String, pushRegistrationId: String?) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
	}
}

struct MessagesSyncRequest: PostRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = MessagesSyncResponse
	var retryLimit: Int = 2
	func mustRetryOnResponseError(_ error: NSError) -> Bool {
		return retryLimit > 0 && error.mm_isRetryable
	}
	var path: APIPath { return .SyncMessages }
	var parameters: RequestParameters? {
		var params = RequestParameters()
		params[Consts.PushRegistration.platform] = Consts.APIValues.platformType
		return params
	}

	let archiveMsgIds: [String]?
	let dlrMsgIds: [String]?

	var body: RequestBody? {
		var result = RequestBody()
		result[Consts.APIKeys.archiveMsgIds] = (archiveMsgIds?.isEmpty ?? true) ? nil : archiveMsgIds
		result[Consts.APIKeys.DLRMsgIds] = (dlrMsgIds?.isEmpty ?? true) ? nil : dlrMsgIds
		return result
	}

	init(applicationCode: String, pushRegistrationId: String, archiveMsgIds: [String]?, dlrMsgIds: [String]?) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.archiveMsgIds = archiveMsgIds
		self.dlrMsgIds = dlrMsgIds
	}
}

struct DeliveryReportRequest: PostRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = DeliveryReportResponse
	var path: APIPath { return .DeliveryReport }
	let dlrIds: [String]
	var body: RequestBody? { return [Consts.DeliveryReport.dlrMessageIds: dlrIds] }
	
	init?(applicationCode: String, dlrIds: [String]?) {
		guard let dlrIds = dlrIds else {
			return nil
		}
		self.applicationCode = applicationCode
		self.pushRegistrationId = nil
		self.dlrIds = dlrIds
	}
}

typealias UserDataDictionary = [String: Any]
struct UserDataRequest: PostRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = UserDataSyncResponse
	var path: APIPath { return .UserData }
	var parameters: RequestParameters? {
		var params = RequestParameters()
		if let externalUserId = externalUserId {
			params[Consts.APIKeys.UserData.externalUserId] = externalUserId
		}
		return params
	}
	var body: RequestBody? {
		var result = RequestBody()
		if let predefinedUserData = predefinedUserData, !predefinedUserData.isEmpty {
			result[Consts.APIKeys.UserData.predefinedUserData] = predefinedUserData
		}
		if let customUserData = customUserData, !customUserData.isEmpty {
			result[Consts.APIKeys.UserData.customUserData] = customUserData.reduce(UserDataDictionary(), { (result, element) -> UserDataDictionary in
				return result + element.dictionaryRepresentation
			})
		}
		return result.isEmpty == true ? nil : result
	}

	let externalUserId: String?
	let predefinedUserData: UserDataDictionary?
	let customUserData: [CustomUserData]?

	init(applicationCode: String, pushRegistrationId: String, externalUserId: String?, predefinedUserData: UserDataDictionary? = nil, customUserData: [String: CustomUserDataValue]? = nil) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.externalUserId = externalUserId
		self.predefinedUserData = predefinedUserData
		if let customUserData = customUserData {
			self.customUserData = customUserData.map{ CustomUserData(dataKey: $0.0, dataValue: $0.1.dataValue) }
		} else {
			self.customUserData = nil
		}
	}
}

struct SystemDataSyncRequest: PostRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = SystemDataSyncResponse
	var path: APIPath { return .SystemData }
	var body: RequestBody? {
		return systemData.dictionaryRepresentation
	}

	let systemData: SystemData

	init(applicationCode: String, pushRegistrationId: String, systemData: SystemData) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.systemData = systemData
	}
}

struct LogoutRequest: PostRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = LogoutResponse
	var path: APIPath { return .Logout }
	var retryLimit: Int = 3

	init(applicationCode: String, pushRegistrationId: String) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
	}
}

struct MOMessageSendingRequest: PostRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = MOMessageSendingResponse
	var path: APIPath { return .MOMessage }
	var parameters: RequestParameters? {
		return [Consts.PushRegistration.platform : Consts.APIValues.platformType]
	}
	var body: RequestBody? {
		var result = RequestBody()
		result[Consts.APIKeys.MO.from] = pushRegistrationId
		result[Consts.APIKeys.MO.messages] = messages.map { msg -> RequestBody in
			var dict = msg.dictRepresentation
			dict[Consts.APIKeys.MO.messageSentStatusCode] = nil // this attribute is redundant, the Mobile API would not expect it.
			return dict
		}
		return result
	}

	let messages: [MOMessage]

	init(applicationCode: String, pushRegistrationId: String, messages: [MOMessage]) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.messages = messages
	}
}

//MARK: - Base

typealias RequestBody = [String: Any]
typealias RequestParameters = [String: Any]
typealias RequestHeaders = [String: String]

enum Method: String {
	case POST
	case PUT
	case GET
}

protocol RequestResponsable {
	associatedtype ResponseType: JSONDecodable
}

protocol RequestData: RequestResponsable {
	var applicationCode: String {get}
	var pushRegistrationId: String? {get}
	var method: Method {get}
	var path: APIPath {get}
	var parameters: RequestParameters? {get}
	var headers: RequestHeaders? {get}
	var retryLimit: Int {get}
	var body: RequestBody? {get}
	func mustRetryOnResponseError(_ error: NSError) -> Bool
}

protocol GetRequest: RequestData { }
extension GetRequest {
	var method: Method { return .GET }
}

protocol PostRequest: RequestData { }
extension PostRequest {
	var method: Method { return .POST }
}

protocol PutRequest: RequestData { }
extension PutRequest {
	var method: Method { return .PUT }
}

extension RequestData {
	func mustRetryOnResponseError(_ error: NSError) -> Bool {
		return retryLimit > 0 && error.mm_isCannotFindHost
	}
	var retryLimit: Int { return 1 }
	var headers: RequestHeaders? { return nil }
	var body: RequestBody? { return nil }
	var parameters: RequestParameters? { return nil }
}

struct SeenData: DictionaryRepresentable {
	let messageId: String
	let seenDate: Date
	init(messageId: String, seenDate: Date) {
		self.messageId = messageId
		self.seenDate = seenDate
	}
	init?(dictRepresentation dict: DictionaryRepresentation) {
		return nil // unused
	}
	var dictionaryRepresentation: DictionaryRepresentation {
		return [Consts.APIKeys.messageId: messageId,
		        Consts.APIKeys.seenTimestampDelta: seenDate.timestampDelta]
	}
	static func requestBody(seenList: [SeenData]) -> RequestBody {
		return [Consts.APIKeys.seenMessages: seenList.map{ $0.dictionaryRepresentation } ]
	}
}
