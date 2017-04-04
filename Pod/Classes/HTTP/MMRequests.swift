//
//  MMRequests.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//
//

enum APIPath: String {
	case Registration = "/mobile/2/registration"
	case SeenMessages = "/mobile/1/messages/seen"
	case SyncMessages = "/mobile/3/messages"
	case UserData = "/mobile/3/data/user"
	case MOMessage = "/mobile/1/messages/mo"
	case SystemData = "/mobile/1/data/system"
	case LibraryVersion = "/mobile/3/version"
	case GeoEventsReports = "/mobile/4/geo/event"
}

struct RegistrationRequest: PostRequest {
	typealias ResponseType = RegistrationResponse
	var retryLimit: Int { return 3 }
	var path: APIPath { return .Registration }
	var parameters: RequestParameters? {
		var params: RequestParameters = [PushRegistration.deviceToken: deviceToken,
										 PushRegistration.platform: APIValues.platformType]
		params[PushRegistration.internalId] = internalId
		params[PushRegistration.expiredInternalId] = expiredInternalId
		if let isEnabled = isEnabled {
			params[PushRegistration.isEnabled] = isEnabled ? 1 : 0
		}
		return params
	}
	let deviceToken: String
	let isEnabled: Bool?
	let internalId: String?
	let expiredInternalId: String?
	
	init(deviceToken: String, internalId: String?, isEnabled: Bool?, expiredInternalId: String?) {
		self.internalId = internalId
		self.deviceToken = deviceToken
		self.isEnabled = isEnabled
		self.expiredInternalId = expiredInternalId
	}
}

struct SeenStatusSendingRequest: PostRequest {
	typealias ResponseType = SeenStatusSendingResponse
	var path: APIPath { return .SeenMessages }
	var parameters: RequestParameters? { return nil }
	
	let seenList: [SeenData]
	var body: RequestBody? { return SeenData.requestBody(seenList: seenList) }
	
	init(seenList: [SeenData]) {
		self.seenList = seenList
	}
}

struct LibraryVersionRequest: GetRequest {
	typealias ResponseType = LibraryVersionResponse
	var path: APIPath { return .LibraryVersion }
	var parameters: [String: Any]? = [PushRegistration.platform: APIValues.platformType]
}

struct MessagesSyncRequest: PostRequest {
	
	typealias ResponseType = MessagesSyncResponse
	var retryLimit: Int = 2
	var path: APIPath { return .SyncMessages }
	var parameters: RequestParameters? {
		var params = RequestParameters()
		params[PushRegistration.internalId] = internalId
		params[PushRegistration.platform] = APIValues.platformType
		return params
	}
	
	let internalId: String
	let archiveMsgIds: [String]?
	let dlrMsgIds: [String]?

	var body: RequestBody? {
		var result = RequestBody()
		result[APIKeys.kArchiveMsgIds] = (archiveMsgIds?.isEmpty ?? true) ? nil : archiveMsgIds
		result[APIKeys.kDLRMsgIds] = (dlrMsgIds?.isEmpty ?? true) ? nil : dlrMsgIds
		return result
	}
	
	init(internalId: String, archiveMsgIds: [String]?, dlrMsgIds: [String]?) {
		self.internalId = internalId
		self.archiveMsgIds = archiveMsgIds
		self.dlrMsgIds = dlrMsgIds
	}
}

typealias UserDataDictionary = [String: Any]
struct UserDataRequest: PostRequest {
	typealias ResponseType = UserDataSyncResponse
	var path: APIPath { return .UserData }
	var parameters: RequestParameters? {
		var params = [PushRegistration.internalId: internalUserId]
		if let externalUserId = externalUserId {
			params[APIKeys.kUserDataExternalUserId] = externalUserId
		}
		return params
	}
	var body: RequestBody? {
		var result = RequestBody()
		result[APIKeys.kUserDataPredefinedUserData] = predefinedUserData ?? UserDataDictionary()
		if let customUserData = customUserData {
			result[APIKeys.kUserDataCustomUserData] = customUserData.reduce(UserDataDictionary(), { (result, element) -> UserDataDictionary in
				return result + element.dictionaryRepresentation
			})
		} else {
			result[APIKeys.kUserDataCustomUserData] = UserDataDictionary()
		}
		return result
	}
	
	let internalUserId: String
	let externalUserId: String?
	let predefinedUserData: UserDataDictionary?
	let customUserData: [CustomUserData]?
	
	init(internalUserId: String, externalUserId: String?, predefinedUserData: UserDataDictionary? = nil, customUserData: [String: CustomUserDataValue]? = nil) {
		self.internalUserId = internalUserId
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
	typealias ResponseType = SystemDataSyncResponse
	var path: APIPath { return .SystemData }
	var parameters: RequestParameters? {
		return [PushRegistration.internalId: internalUserId]
	}
	var body: RequestBody? {
		return systemData.dictionaryRepresentation
	}
	
	let internalUserId: String
	let systemData: MMSystemData
	
	init(internalUserId: String, systemData: MMSystemData) {
		self.internalUserId = internalUserId
		self.systemData = systemData
	}
}

struct MOMessageSendingRequest: PostRequest {
	typealias ResponseType = MOMessageSendingResponse
	var path: APIPath { return .MOMessage }
	var parameters: RequestParameters? {
		return [PushRegistration.platform : APIValues.platformType]
	}
	var body: RequestBody? {
		var result = RequestBody()
		result[APIKeys.kMOFrom] = internalUserId
		result[APIKeys.kMOMessages] = messages.map { msg -> RequestBody in
			var dict = msg.dictRepresentation
			dict[APIKeys.kMOMessageSentStatusCode] = nil // this attribute is redundant, the Mobile API would not expect it.
			return dict
		}
		return result
	}
	
	let internalUserId: String
	let messages: [MOMessage]
	
	init(internalUserId: String, messages: [MOMessage]) {
		self.internalUserId = internalUserId
		self.messages = messages
	}
}

struct GeoEventReportingRequest: PostRequest {
	typealias ResponseType = GeoEventReportingResponse
	
	var path: APIPath { return .GeoEventsReports }
	var body: RequestBody? {
		return [
            PushRegistration.platform: APIValues.platformType,
            PushRegistration.internalId: internalUserId,
            GeoReportingAPIKeys.reports: eventsDataList.map { $0.dictionaryRepresentation },
            GeoReportingAPIKeys.messages: geoMessages.map { $0.geoEventReportFormat }
        ]
	}
	
    let internalUserId: String
	let eventsDataList: [GeoEventReportData]
	let geoMessages: [MMGeoMessage]
	
	init(internalUserId: String, eventsDataList: [GeoEventReportData], geoMessages: [MMGeoMessage]) {
        self.internalUserId = internalUserId
		self.eventsDataList = eventsDataList
		self.geoMessages = geoMessages
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
	func responseObject(applicationCode: String, baseURL: String, completion: @escaping (Result<ResponseType>) -> Void)
}

protocol RequestData: RequestResponsable {
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

extension RequestData {
	func mustRetryOnResponseError(_ error: NSError) -> Bool {
		return retryLimit > 0 && error.mm_isRetryable
	}
	var retryLimit: Int { return 0 }
	var headers: RequestHeaders? { return nil }
	var body: RequestBody? { return nil }
	var parameters: RequestParameters? { return nil }
	func responseObject(applicationCode: String, baseURL: String, completion: @escaping (Result<ResponseType>) -> Void) {
		let manager = MM_AFHTTPSessionManager(baseURL: URL(string: baseURL), sessionConfiguration: MobileMessaging.urlSessionConfiguration)
		manager.requestSerializer = RequestSerializer(applicationCode: applicationCode, jsonBody: body, headers: headers)
		manager.responseSerializer = ResponseSerializer<ResponseType>()
		
		MMLogDebug("Sending request \(type(of: self))\nparameters: \(String(describing: parameters))\nbody: \(String(describing: body))\nto \(baseURL + path.rawValue)")
		
		let successBlock = { (task: URLSessionDataTask, obj: Any?) -> Void in
			if let obj = obj as? ResponseType {
				completion(Result.Success(obj))
			} else {
				let error = NSError(domain: AFURLResponseSerializationErrorDomain, code: NSURLErrorCannotDecodeContentData, userInfo:[NSLocalizedFailureReasonErrorKey : "Request succeeded with no return value or return value wasn't a ResponseType value."])
				completion(Result.Failure(error))
			}
		}
		
		let failureBlock = { (task: URLSessionDataTask?, error: Error) -> Void in
			completion(Result<ResponseType>.Failure(error as NSError?))
		}
		
		let urlString = manager.baseURL!.absoluteString + self.path.rawValue
		switch self.method {
		case .POST:
			manager.post(urlString, parameters: parameters, progress: nil, success: successBlock, failure: failureBlock)
		case .PUT:
			manager.put(urlString, parameters: parameters, success: successBlock, failure: failureBlock)
		case .GET:
			manager.get(urlString, parameters: parameters, progress: nil, success: successBlock, failure: failureBlock)
		}
	}
}

struct GeoEventReportData: DictionaryRepresentable {
	let campaignId: String
	let eventDate: Date
	let geoAreaId: String
	let messageId: String
	let sdkMessageId: String
	let eventType: RegionEventType
	
	init(geoAreaId: String, eventType: RegionEventType, campaignId: String, eventDate: Date, sdkMessageId: String, messageId: String) {
		self.campaignId = campaignId
		self.eventDate = eventDate
		self.geoAreaId = geoAreaId
		self.eventType = eventType
		self.messageId = messageId
		self.sdkMessageId = sdkMessageId
	}
	
	init?(dictRepresentation dict: DictionaryRepresentation) {
		return nil // unused
	}
	
	var dictionaryRepresentation: DictionaryRepresentation {
		return [GeoReportingAPIKeys.campaignId: campaignId,
		        GeoReportingAPIKeys.timestampDelta: eventDate.timestampDelta,
		        GeoReportingAPIKeys.geoAreaId: geoAreaId,
		        GeoReportingAPIKeys.event: eventType.rawValue,
		        GeoReportingAPIKeys.messageId: messageId,
		        GeoReportingAPIKeys.sdkMessageId: sdkMessageId
		]
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
		return [APIKeys.kMessageId: messageId,
		        APIKeys.kSeenTimestampDelta: seenDate.timestampDelta]
	}
	static func requestBody(seenList: [SeenData]) -> RequestBody {
		return [APIKeys.kSeenMessages: seenList.map{ $0.dictionaryRepresentation } ]
	}
}
