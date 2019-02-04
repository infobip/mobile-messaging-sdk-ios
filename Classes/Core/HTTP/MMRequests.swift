//
//  MMRequests.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//

enum APIPath: String {
	case SeenMessages = "/mobile/1/messages/seen"
	case SyncMessages = "/mobile/5/messages"
	case MOMessage = "/mobile/1/messages/mo"
	case LibraryVersion = "/mobile/3/version"
	case GeoEventsReports = "/mobile/4/geo/event"
	case DeliveryReport = "/mobile/1/messages/deliveryreport"

	case AppInstancePersonalize = "/mobile/1/appinstance/{pushRegistrationId}/personalize"
	case AppInstanceDepersonalize = "/mobile/1/appinstance/{pushRegistrationId}/depersonalize"
	case AppInstanceUser_CRUD = "/mobile/1/appinstance/{pushRegistrationId}/user"
	case AppInstance_xRUD = "/mobile/1/appinstance/{pushRegistrationId}"
	case AppInstance_Cxxx = "/mobile/1/appinstance"
}

struct SeenStatusSendingRequest: PostRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	typealias ResponseType = EmptyResponse
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
	typealias ResponseType = EmptyResponse
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
	case PATCH
	case DELETE
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
	var pathParameters: [String: String]? {get}
	var headers: RequestHeaders? {get}
	var retryLimit: Int {get}
	var body: RequestBody? {get}
	func mustRetryOnResponseError(_ error: NSError) -> Bool
}

protocol GetRequest: RequestData { }
extension GetRequest {
	var method: Method { return .GET }
	var body: RequestBody? { return nil }
}

protocol PostRequest: RequestData { }
extension PostRequest {
	var method: Method { return .POST }
}

protocol DeleteRequest: RequestData { }
extension DeleteRequest {
	var method: Method { return .DELETE }
}

protocol PutRequest: RequestData { }
extension PutRequest {
	var method: Method { return .PUT }
}

protocol PatchRequest: RequestData { }
extension PatchRequest {
	var method: Method { return .PATCH }
}


extension RequestData {
	func mustRetryOnResponseError(_ error: NSError) -> Bool {
		return retryLimit > 0 && error.mm_isCannotFindHost
	}
	var retryLimit: Int { return 1 }
	var headers: RequestHeaders? { return nil }
	var body: RequestBody? { return nil }
	var parameters: RequestParameters? { return nil }
	var pathParameters: [String: String]? { return nil }

	var resolvedPath: String {
		var ret: String = path.rawValue
		pathParameters?.forEach { (pathParameterName, pathParameterValue) in
			ret = ret.replacingOccurrences(of: pathParameterName, with: pathParameterValue)
		}
		return ret
	}
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
