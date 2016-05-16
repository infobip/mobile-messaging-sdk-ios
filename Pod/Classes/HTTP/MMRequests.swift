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
    case FetchMessages = "/mobile/1/messages"
	case Email = "/mobile/1/email"
	case MSISDN = "/mobile/1/msisdn"
    case SeenMessages = "/mobile/1/messages/seen"
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

extension MMHTTPRequestData {
	var retryLimit: Int { return 0 }
	var headers: [String: String]? { return nil }
    var body: [String: AnyObject]? { return nil }
    
	func responseObject(applicationCode: String, baseURL: String, completion: Result<ResponseType> -> Void) {
		MMHTTPSessionManager.sendRequest(self, baseURL: baseURL, applicationCode: applicationCode, completion: completion)
	}
}

struct MMPostRegistrationRequest: MMHTTPRequestData {
	typealias ResponseType = MMHTTPRegistrationResponse
	
	var retryLimit: Int { return 3 }
	var method: MMHTTPMethod { return .POST }
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

struct MMPostDeliveryReportRequest: MMHTTPRequestData {
	typealias ResponseType = MMHTTPDeliveryReportingResponse
	
	var method: MMHTTPMethod { return .POST }
	var path: MMHTTPAPIPath { return .DeliveryReport }
	var parameters: [String: AnyObject]? { return [MMAPIKeys.kMessageIDs: messageIDs] }
	var messageIDs: [String]
	
	init(messageIDs: [String]) {
		self.messageIDs = messageIDs
	}
}

struct MMGetMessagesRequest: MMHTTPRequestData {
	typealias ResponseType = MMHTTPFetchMessagesResponse
	
	var method: MMHTTPMethod { return .GET }
	var path: MMHTTPAPIPath { return .FetchMessages }
	var parameters: [String: AnyObject]? {
		return [MMAPIKeys.kInternalRegistrationId: internalId] + (messageIds.count > 0 ? [MMAPIKeys.kMessageIDs: messageIds] : nil)
	}
	var messageIds: [String]
	var internalId: String
	
	init(messageIds: [String], internalId: String) {
		self.messageIds = messageIds
		self.internalId = internalId
	}
}

struct MMPostMSISDNRequest: MMHTTPRequestData {
	typealias ResponseType = MMHTTPSaveMSISDNResponse
	
	var method: MMHTTPMethod { return .POST }
	var path: MMHTTPAPIPath { return .MSISDN }
	var parameters: [String: AnyObject]? { return [MMAPIKeys.kInternalRegistrationId: internalId, MMAPIKeys.kMSISDN: msisdn] }
	var msisdn: String
	var internalId: String
	
	init(internalId: String, msisdn: String?) {
		self.internalId = internalId
		self.msisdn = msisdn ?? ""
	}
}

struct MMPostSeenMessagesRequest: MMHTTPRequestData {
	typealias ResponseType = MMHTTPSeenMessagesResponse
	
	var method: MMHTTPMethod { return .POST }
	var path: MMHTTPAPIPath { return .SeenMessages }
	var parameters: [String: AnyObject]? { return nil }
	var seenList: [SeenData]
    var body: [String: AnyObject]? { return SeenData.requestBody(seenList) }
	
	init(seenList: [SeenData]) {
		self.seenList = seenList
	}
}

struct MMPostEmailRequest: MMHTTPRequestData {
	typealias ResponseType = MMHTTPSaveEmailResponse
	
	var method: MMHTTPMethod { return .POST }
	var path: MMHTTPAPIPath { return .Email }
	var parameters: [String: AnyObject]? { return [MMAPIKeys.kInternalRegistrationId: internalId, MMAPIKeys.kEmail: email] }
	var email: String
	var internalId: String
	
	init(internalId: String, email: String?) {
		self.internalId = internalId
		self.email = email ?? ""
	}
}
