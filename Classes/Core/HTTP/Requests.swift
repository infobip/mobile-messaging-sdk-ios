//
//  Requests.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01/11/2018.
//

import Foundation

struct GetInstance: GetRequest {
	var returnPushServiceToken: Bool
	var parameters: RequestParameters? { return ["rt": returnPushServiceToken] }
	var applicationCode: String
	var pushRegistrationId: String?
	var pathParameters: [String: String]? { return ["{pushRegistrationId}": pushRegistrationId!] }
	var path: APIPath { return APIPath.AppInstance_xRUD }
	typealias ResponseType = Installation

	init(applicationCode: String, pushRegistrationId: String, returnPushServiceToken: Bool) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.returnPushServiceToken = returnPushServiceToken
	}
}

struct PatchInstance: PatchRequest {
	let refPushRegistrationId: String
	var returnPushServiceToken: Bool
	var parameters: RequestParameters? { return ["rt": returnPushServiceToken] }
	var applicationCode: String
	var pushRegistrationId: String?
	var body: RequestBody?
	var pathParameters: [String: String]? { return ["{pushRegistrationId}": refPushRegistrationId] }
	var path: APIPath { return APIPath.AppInstance_xRUD }
	typealias ResponseType = EmptyResponse

	init?(applicationCode: String, authPushRegistrationId: String, refPushRegistrationId: String, body: RequestBody, returnPushServiceToken: Bool) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = authPushRegistrationId
		self.refPushRegistrationId = refPushRegistrationId
		self.body = body
		self.returnPushServiceToken = returnPushServiceToken
		if self.body?.isEmpty ?? true {
			return nil
		}
	}
}

struct PostInstance: PostRequest {
	var returnPushServiceToken: Bool
	var parameters: RequestParameters? { return ["rt": returnPushServiceToken] }
	var applicationCode: String
	var pushRegistrationId: String?
	var body: RequestBody?
	var pathParameters: [String: String]?
	var path: APIPath { return APIPath.AppInstance_Cxxx }
	typealias ResponseType = Installation

	init?(applicationCode: String, body: RequestBody, returnPushServiceToken: Bool) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = nil
		self.body = body
		self.returnPushServiceToken = returnPushServiceToken
		if self.body?.isEmpty ?? true {
			return nil
		}
	}
}

struct DeleteInstance: DeleteRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	let expiredPushRegistrationId: String
	var body: RequestBody?
	var pathParameters: [String: String]? { return ["{pushRegistrationId}": expiredPushRegistrationId] }
	var path: APIPath { return APIPath.AppInstance_xRUD }
	typealias ResponseType = EmptyResponse

	init(applicationCode: String, pushRegistrationId: String, expiredPushRegistrationId: String) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.expiredPushRegistrationId = expiredPushRegistrationId
	}
}

class GetUser: GetRequest {
	let returnPushServiceToken: Bool
	let returnInstance: Bool
	var parameters: RequestParameters? { return ["rt": returnPushServiceToken, "ri": returnInstance] }
	var applicationCode: String
	var pushRegistrationId: String?
	var pathParameters: [String: String]? { return ["{pushRegistrationId}": pushRegistrationId!] }
	var path: APIPath { return APIPath.AppInstanceUser_CRUD }

	typealias ResponseType = User

	init(applicationCode: String, pushRegistrationId: String, returnInstance: Bool, returnPushServiceToken: Bool) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.returnInstance = returnInstance
		self.returnPushServiceToken = returnPushServiceToken
	}
}

class PatchUser: PatchRequest {
	let returnPushServiceToken: Bool
	let returnInstance: Bool
	var parameters: RequestParameters? { return ["rt": returnPushServiceToken, "ri": returnInstance] }
	var applicationCode: String
	var pushRegistrationId: String?
	var pathParameters: [String: String]? { return ["{pushRegistrationId}": pushRegistrationId!] }
	var path: APIPath { return APIPath.AppInstanceUser_CRUD }
	var body: RequestBody?

	typealias ResponseType = EmptyResponse

	init?(applicationCode: String, pushRegistrationId: String, body: RequestBody, returnInstance: Bool, returnPushServiceToken: Bool) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.returnInstance = returnInstance
		self.returnPushServiceToken = returnPushServiceToken
		self.body = body
		if self.body?.isEmpty ?? true {
			return nil
		}
	}
}

class PostDepersonalize: PostRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	let pushRegistrationIdToDepersonalize: String
	var pathParameters: [String: String]? { return ["{pushRegistrationId}": pushRegistrationIdToDepersonalize] }
	var path: APIPath { return .AppInstanceDepersonalize }

	typealias ResponseType = EmptyResponse

	init(applicationCode: String, pushRegistrationId: String, pushRegistrationIdToDepersonalize: String) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.pushRegistrationIdToDepersonalize = pushRegistrationIdToDepersonalize
	}
}

class PostPersonalize: PostRequest {
	var applicationCode: String
	var pushRegistrationId: String?
	var pathParameters: [String: String]? { return ["{pushRegistrationId}": pushRegistrationId!] }
	var path: APIPath { return .AppInstancePersonalize }
	var body: RequestBody?
	let forceDepersonalize: Bool
	var parameters: RequestParameters? {
		return ["forceDepersonalize": forceDepersonalize]
	}

	typealias ResponseType = User

	init(applicationCode: String, pushRegistrationId: String, body: RequestBody, forceDepersonalize: Bool) {
		self.applicationCode = applicationCode
		self.pushRegistrationId = pushRegistrationId
		self.body = body
		self.forceDepersonalize = forceDepersonalize
	}
}
