//
//  MMRequests.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//  
//
//import SwiftyJSON

enum MMHTTPRequestError: Error {
    case EmptyDeviceToken
    case IncorrectApplicationCode
}

enum MMHTTPMethod {
	case POST
	case PUT
	case GET
}

enum MMHTTPAPIPath: String {
    case Registration = "/mobile/2/registration"
    case SeenMessages = "/mobile/1/messages/seen"
	case SyncMessages = "/mobile/3/messages"
	case UserData = "/mobile/2/data/user"
	case MOMessage = "/mobile/1/messages/mo"
	case SystemData = "/mobile/1/data/system"
}

protocol MMHTTPRequestResponsable {
	associatedtype ResponseType: JSONDecodable
	func responseObject(applicationCode: String, baseURL: String, completion: @escaping (Result<ResponseType>) -> Void)
}

protocol MMHTTPRequestData: MMHTTPRequestResponsable {
	var method: MMHTTPMethod {get}
	var path: MMHTTPAPIPath {get}
	var parameters: [String: Any]? {get}
	var headers: [String: String]? {get}
	var retryLimit: Int {get}
    var body: [String: Any]? {get}
}

protocol MMHTTPGetRequest: MMHTTPRequestData { }
extension MMHTTPGetRequest {
	var method: MMHTTPMethod { return .GET }
}

protocol MMHTTPPostRequest: MMHTTPRequestData { }
extension MMHTTPPostRequest {
	var method: MMHTTPMethod { return .POST }
}

extension MMHTTPRequestData {
	var retryLimit: Int { return 0 }
	var headers: [String: String]? { return nil }
    var body: [String: Any]? { return nil }
	var parameters: [String: Any]? { return nil }
    
	func responseObject(applicationCode: String, baseURL: String, completion: @escaping (Result<ResponseType>) -> Void) {
		let manager = MM_AFHTTPSessionManager(baseURL: URL(string: baseURL), sessionConfiguration: URLSessionConfiguration.default)
		manager.requestSerializer = MMHTTPRequestSerializer(applicationCode: applicationCode, jsonBody: body, headers: headers)
		manager.responseSerializer = MMResponseSerializer<ResponseType>()
		
		MMLogDebug("Sending request \(type(of: self))\nparameters: \(parameters)\nbody: \(body)\nto \(baseURL + path.rawValue)")
		
		let successBlock = { (task: URLSessionDataTask, obj: Any?) -> Void in
			if let obj = obj as? ResponseType {
				completion(Result.Success(obj))
			} else {
				let error = NSError(domain: AFURLResponseSerializationErrorDomain, code: NSURLErrorCannotDecodeContentData, userInfo:nil)
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

struct MMPostRegistrationRequest: MMHTTPPostRequest {
	typealias ResponseType = MMHTTPRegistrationResponse
	
	var retryLimit: Int { return 3 }
	var path: MMHTTPAPIPath { return .Registration }
    var parameters: [String: Any]? {
        var params = [MMAPIKeys.kRegistrationId: currentDeviceToken,
                      MMAPIKeys.kPlatformType: MMAPIValues.kPlatformType]
		params[MMAPIKeys.kInternalRegistrationId] = internalId
        return params
    }
    let currentDeviceToken: String
	let internalId: String?

    init(internalId: String?, deviceToken: String) {
		self.internalId = internalId
		self.currentDeviceToken = deviceToken
	}
}

struct SeenData {
	let messageId: String
	let seenDate: NSDate
	var timestampDelta: UInt {
		return UInt(max(0, NSDate().timeIntervalSinceReferenceDate - seenDate.timeIntervalSinceReferenceDate))
	}
	var dict: [String: Any] {
		return [MMAPIKeys.kMessageId: messageId,
		        MMAPIKeys.kSeenTimestampDelta: timestampDelta]
	}
	static func requestBody(seenList: [SeenData]) -> [String: Any] {
		return [MMAPIKeys.kSeenMessages: seenList.map{ $0.dict } ]
	}
}

struct MMPostSeenMessagesRequest: MMHTTPPostRequest {
	typealias ResponseType = MMHTTPSeenMessagesResponse
	
	var path: MMHTTPAPIPath { return .SeenMessages }
	var parameters: [String: Any]? { return nil }
	let seenList: [SeenData]
    var body: [String: Any]? { return SeenData.requestBody(seenList: seenList) }
	
	init(seenList: [SeenData]) {
		self.seenList = seenList
	}
}

struct MMPostSyncRequest: MMHTTPPostRequest {

	typealias ResponseType = MMHTTPSyncMessagesResponse
	var path: MMHTTPAPIPath { return .SyncMessages }
	var parameters: [String: Any]? {
		var params = [String: Any]()
		params[MMAPIKeys.kInternalRegistrationId] = internalId
		params[MMAPIKeys.kPlatformType] = MMAPIValues.kPlatformType
		return params
	}
	
	let internalId: String
	let archiveMsgIds: [String]?
	let dlrMsgIds: [String]?
	var body: [String: Any]? {
		var result = [String: Any]()
		result[MMAPIKeys.kArchiveMsgIds] = (archiveMsgIds?.isEmpty ?? true) ? nil : archiveMsgIds
		result[MMAPIKeys.kDLRMsgIds] = (dlrMsgIds?.isEmpty ?? true) ? nil : dlrMsgIds
		return result
	}
	
	init(internalId: String, archiveMsgIds: [String]?, dlrMsgIds: [String]?) {
		self.internalId = internalId
		self.archiveMsgIds = archiveMsgIds
		self.dlrMsgIds = dlrMsgIds
	}
}

struct MMPostUserDataRequest: MMHTTPPostRequest {
	typealias ResponseType = MMHTTPUserDataSyncResponse
	var path: MMHTTPAPIPath { return .UserData }
	var parameters: [String: Any]? {
		var params = [MMAPIKeys.kInternalRegistrationId: internalUserId]
		if let externalUserId = externalUserId {
			params[MMAPIKeys.kUserDataExternalUserId] = externalUserId
		}
		return params as [String : AnyObject]
	}
	var body: [String: Any]? {
		var result = [String: Any]()
		result[MMAPIKeys.kUserDataPredefinedUserData] = predefinedUserData ?? [String: Any]()
		result[MMAPIKeys.kUserDataCustomUserData] = customUserData ?? [String: Any]()
		return result
	}
	
	let internalUserId: String
	let externalUserId: String?
	let predefinedUserData: [String: AnyObject]?
	let customUserData: [String: AnyObject]?
	
	init(internalUserId: String, externalUserId: String?, predefinedUserData: [String: AnyObject]? = nil, customUserData: [String: AnyObject]? = nil) {
		self.internalUserId = internalUserId
		self.externalUserId = externalUserId //???: what if I send nil after I sent non-nil earlier?
		self.predefinedUserData = predefinedUserData
		self.customUserData = customUserData
	}
}


func ==(lhs: MMSystemData, rhs: MMSystemData) -> Bool {
	return lhs.hashValue == rhs.hashValue
}
struct MMSystemData: Hashable {
	let SDKVersion, OSVer, deviceManufcturer, deviceModel, appVer: String
	let geoAvailability: Bool
	var dictionaryRepresentation: [String: Any] {
		return [
			MMAPIKeys.kSystemDataSDKVersion: SDKVersion,
			MMAPIKeys.kSystemDataOSVer: OSVer,
			MMAPIKeys.kSystemDataDeviceManufacturer: deviceManufcturer,
			MMAPIKeys.kSystemDataDeviceModel: deviceModel,
			MMAPIKeys.kSystemDataAppVer: appVer,
			MMAPIKeys.kSystemDataGeoAvailability: geoAvailability
		]
	}
	
	var hashValue: Int {
		return (SDKVersion + OSVer + deviceManufcturer + deviceModel + appVer + String(geoAvailability)).hash
	}
	
	static func currentSystemData(userAgent: MMUserAgent) -> MMSystemData {
		return MMSystemData(SDKVersion: userAgent.libraryVersion, OSVer: userAgent.osVersion, deviceManufcturer: userAgent.deviceManufacturer, deviceModel: userAgent.deviceName, appVer: userAgent.hostingAppVersion, geoAvailability: MobileMessaging.geofencingService.isAvailable)
	}
}

struct MMPostSystemDataRequest: MMHTTPPostRequest {
	typealias ResponseType = MMHTTPSystemDataSyncResponse
	var path: MMHTTPAPIPath { return .SystemData }
	var parameters: [String: Any]? {
		return [MMAPIKeys.kInternalRegistrationId: internalUserId]
	}
	var body: [String: Any]? {
		return systemData.dictionaryRepresentation
	}
	
	let internalUserId: String
	let systemData: MMSystemData
	
	init(internalUserId: String, systemData: MMSystemData) {
		self.internalUserId = internalUserId
		self.systemData = systemData
	}
}

struct MMPostMessageRequest: MMHTTPPostRequest {

	typealias ResponseType = MMHTTPMOMessageResponse
	var path: MMHTTPAPIPath { return .MOMessage }
	var parameters: [String: Any]? {
		return [MMAPIKeys.kPlatformType : MMAPIValues.kPlatformType]
	}
	var body: [String: Any]? {
		var result = [String: Any]()
		result[MMAPIKeys.kMOFrom] = internalUserId
		result[MMAPIKeys.kMOMessages] = messages.map { $0.dictRepresentation }
		return result
	}
	
	let internalUserId: String
	let messages: [MOMessage]
	
	init?(internalUserId: String, messages: [MOMessage]) {
		guard !messages.isEmpty else {
			return nil
		}
		self.internalUserId = internalUserId
		self.messages = messages
	}
}
