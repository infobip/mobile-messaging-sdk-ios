//
//  MMRequests.swift
//  MobileMessaging
//
//  Created by Andrey K. on 23/02/16.
//  
//
import Freddy
import MMAFNetworking

enum MMHTTPRequestError: ErrorType {
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
    case DeliveryReport = "/mobile/1/deliveryreports"
	case Email = "/mobile/1/email"
	case MSISDN = "/mobile/1/msisdn"
    case SeenMessages = "/mobile/1/messages/seen"
	case SyncMessages = "/mobile/1/messages"
}

protocol MMHTTPRequestResponsable {
	associatedtype ResponseType: JSONDecodable
	func responseObject(applicationCode: String, baseURL: String, completion: Result<ResponseType> -> Void)
}

protocol MMHTTPRequestData: MMHTTPRequestResponsable {
	var method: MMHTTPMethod {get}
	var path: MMHTTPAPIPath {get}
	var parameters: [String: AnyObject]? {get}
	var headers: [String: String]? {get}
	var retryLimit: Int {get}
    var body: [String: AnyObject]? {get}
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
    var body: [String: AnyObject]? { return nil }
    
	func responseObject(applicationCode: String, baseURL: String, completion: Result<ResponseType> -> Void) {
		let manager = MM_AFHTTPSessionManager(baseURL: NSURL(string: baseURL), sessionConfiguration: NSURLSessionConfiguration.defaultSessionConfiguration())
		manager.requestSerializer = MMHTTPRequestSerializer(applicationCode: applicationCode, jsonBody: body, headers: headers)
		manager.responseSerializer = MMResponseSerializer<ResponseType>()
		
		MMLogInfo("Sending request \(self.dynamicType)\nparameters: \(parameters)\nbody: \(body)\nto \(baseURL + path.rawValue)")
		
		let successBlock = { (task: NSURLSessionDataTask, obj: AnyObject?) -> Void in
			if let obj = obj as? ResponseType {
				completion(Result.Success(obj))
			} else {
				let error = NSError(domain: AFURLResponseSerializationErrorDomain, code: NSURLErrorCannotDecodeContentData, userInfo:nil)
				completion(Result.Failure(error))
			}
		}
		
		let failureBlock = { (task: NSURLSessionDataTask?, error: NSError) -> Void in
			completion(Result<ResponseType>.Failure(error))
		}
		
		let urlString = manager.baseURL!.absoluteString + self.path.rawValue
		switch self.method {
		case .POST:
			manager.POST(urlString, parameters: parameters, progress: nil, success: successBlock, failure: failureBlock)
		case .PUT:
			manager.PUT(urlString, parameters: parameters, success: successBlock, failure: failureBlock)
		case .GET:
			manager.GET(urlString, parameters: parameters, progress: nil, success: successBlock, failure: failureBlock)
		}
	}
}

struct MMPostRegistrationRequest: MMHTTPPostRequest {
	typealias ResponseType = MMHTTPRegistrationResponse
	
	var retryLimit: Int { return 3 }
	var path: MMHTTPAPIPath { return .Registration }
    var parameters: [String: AnyObject]? {
        var params = [MMAPIKeys.kRegistrationId: currentDeviceToken,
                      MMAPIKeys.kPlatformType: MMAPIValues.kPlatformType]
        if let internalId = internalId {
            params[MMAPIKeys.kInternalRegistrationId] = internalId
        }
		
        return params
    }
    var currentDeviceToken: String
	var internalId: String?

    init(internalId: String?, deviceToken: String) {
		self.internalId = internalId
		self.currentDeviceToken = deviceToken
	}
}

struct MMPostDeliveryReportRequest: MMHTTPPostRequest {
	typealias ResponseType = MMHTTPDeliveryReportingResponse
	
	var path: MMHTTPAPIPath { return .DeliveryReport }
	var parameters: [String: AnyObject]? { return [MMAPIKeys.kMessageIDs: messageIDs] }
	var messageIDs: [String]
	
	init(messageIDs: [String]) {
		self.messageIDs = messageIDs
	}
}

struct MMPostMSISDNRequest: MMHTTPPostRequest {
	typealias ResponseType = MMHTTPSaveMSISDNResponse
	
	var path: MMHTTPAPIPath { return .MSISDN }
	var parameters: [String: AnyObject]? { return [MMAPIKeys.kInternalRegistrationId: internalId, MMAPIKeys.kMSISDN: msisdn] }
	var msisdn: String
	var internalId: String
	
	init(internalId: String, msisdn: String?) {
		self.internalId = internalId
		self.msisdn = msisdn ?? ""
	}
}

struct SeenData {
	let messageId: String
	let seenDate: NSDate
	var timestampDelta: UInt {
		return UInt(max(0, NSDate().timeIntervalSinceReferenceDate - seenDate.timeIntervalSinceReferenceDate))
	}
	var dict: [String: AnyObject] {
		return [MMAPIKeys.kMessageId: messageId,
		        MMAPIKeys.kSeenTimestampDelta: timestampDelta]
	}
	static func requestBody(seenList: [SeenData]) -> [String: AnyObject] {
		return [MMAPIKeys.kSeenMessages: seenList.map{ $0.dict } ]
	}
}

struct MMPostSeenMessagesRequest: MMHTTPPostRequest {
	typealias ResponseType = MMHTTPSeenMessagesResponse
	
	var path: MMHTTPAPIPath { return .SeenMessages }
	var parameters: [String: AnyObject]? { return nil }
	var seenList: [SeenData]
    var body: [String: AnyObject]? { return SeenData.requestBody(seenList) }
	
	init(seenList: [SeenData]) {
		self.seenList = seenList
	}
}

struct MMPostEmailRequest: MMHTTPPostRequest {
	typealias ResponseType = MMHTTPSaveEmailResponse
	
	var path: MMHTTPAPIPath { return .Email }
	var parameters: [String: AnyObject]? { return [MMAPIKeys.kInternalRegistrationId: internalId, MMAPIKeys.kEmail: email] }
	var email: String
	var internalId: String
	
	init(internalId: String, email: String?) {
		self.internalId = internalId
		self.email = email ?? ""
	}
}

struct MMGetSyncRequest: MMHTTPGetRequest {
	typealias ResponseType = MMHTTPSyncMessagesResponse
	
	var path: MMHTTPAPIPath { return .SyncMessages }
	var parameters: [String: AnyObject]? {
		var params = [String: AnyObject]()
		params[MMAPIKeys.kInternalRegistrationId] = internalId
		params[MMAPIKeys.kArchiveMsgIds] = archiveMsgIds
		params[MMAPIKeys.kDLRMsgIds] = dlrMsgIds
		return params
	}

	var internalId: String
	var archiveMsgIds: [String]?
	var dlrMsgIds: [String]?
	
	init(internalId: String, archiveMsgIds: [String]?, dlrMsgIds: [String]?) {
		self.internalId = internalId
		self.archiveMsgIds = archiveMsgIds
		self.dlrMsgIds = dlrMsgIds
	}
}

