//
//  RemoteAPIProvider.swift
//
//  Created by Andrey K. on 26/11/2016.
//
//

import Foundation

class RemoteAPIProvider: GeneralRemoteAPIProtocol {
	var sessionManager: DynamicBaseUrlHTTPSessionManager

	init(sessionManager: DynamicBaseUrlHTTPSessionManager) {
		self.sessionManager = sessionManager
	}
    
    func getBaseUrl(applicationCode: String, completion: @escaping (BaseUrlResult) -> Void) {
        let request = BaseUrlRequest(applicationCode: applicationCode)
        performRequest(request: request, completion: completion)
    }

	func sendCustomEvent(applicationCode: String, pushRegistrationId: String, validate: Bool, body: RequestBody, completion: @escaping (CustomEventResult) -> Void) {
		let request = PostCustomEvent(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, validate: validate, requestBody: body)
		performRequest(request: request, completion: completion)
	}

	func sendSeenStatus(applicationCode: String, pushRegistrationId: String?, body: RequestBody, completion: @escaping (SeenStatusSendingResult) -> Void) {
		let request = SeenStatusSendingRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body)
		performRequest(request: request, completion: completion)
	}

	func sendUserSessionReport(applicationCode: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (UserSessionSendingResult) -> Void) {
		let request = PostUserSession(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, requestBody: body)
		performRequest(request: request, completion: completion)
	}
	
	func sendMessages(applicationCode: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (MOMessageSendingResult) -> Void) {
		let request = MOMessageSendingRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body)
		performRequest(request: request, completion: completion)
	}
	
	func syncMessages(applicationCode: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (MessagesSyncResult) -> Void) {
		let request = MessagesSyncRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body)
		performRequest(request: request, completion: completion)
	}

	func fetchRecentLibraryVersion(applicationCode: String, pushRegistrationId: String?, completion: @escaping (LibraryVersionResult) -> Void) {
		let request = LibraryVersionRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId)
		performRequest(request: request, completion: completion)
	}
	
//new api
	func depersonalize(applicationCode: String, pushRegistrationId: String, pushRegistrationIdToDepersonalize: String, completion: @escaping (DepersonalizeResult) -> Void) {
		let request = PostDepersonalize(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, pushRegistrationIdToDepersonalize: pushRegistrationIdToDepersonalize)
		performRequest(request: request, completion: completion)
	}

	func personalize(applicationCode: String, pushRegistrationId: String, body: RequestBody, forceDepersonalize: Bool, completion: @escaping (PersonalizeResult) -> Void) {
		let request = PostPersonalize(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body, forceDepersonalize: forceDepersonalize)
		performRequest(request: request, completion: completion)
	}

	func patchUser(applicationCode: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateUserDataResult) -> Void) {
		if let request = PatchUser(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body, returnInstance: false, returnPushServiceToken: false) {
			performRequest(request: request, completion: completion)
		} else {
			completion(.Cancel)
		}
	}

	func getUser(applicationCode: String, pushRegistrationId: String, completion: @escaping (FetchUserDataResult) -> Void) {
		let request = GetUser(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, returnInstance: true, returnPushServiceToken: false)
		performRequest(request: request, completion: completion)
	}

	func patchInstance(applicationCode: String, authPushRegistrationId: String, refPushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		if let request = PatchInstance(applicationCode: applicationCode, authPushRegistrationId: authPushRegistrationId, refPushRegistrationId: refPushRegistrationId, body: body, returnPushServiceToken: false) {
			performRequest(request: request, completion: completion)
		} else {
			completion(.Cancel)
		}
	}

	func postInstance(applicationCode: String, body: RequestBody, completion: @escaping (FetchInstanceDataResult) -> Void) {
		if let request = PostInstance(applicationCode: applicationCode, body: body, returnPushServiceToken: true) {
			performRequest(request: request, completion: completion)
		} else {
			completion(.Cancel)
		}
	}

	func patchOtherInstance(applicationCode: String, authPushRegistrationId: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		if let request = PatchInstance(applicationCode: applicationCode, authPushRegistrationId: authPushRegistrationId, refPushRegistrationId: pushRegistrationId, body: body, returnPushServiceToken: false) {
			performRequest(request: request, completion: completion)
		} else {
			completion(.Cancel)
		}
	}

	func getInstance(applicationCode: String, pushRegistrationId: String, completion: @escaping (FetchInstanceDataResult) -> Void) {
		let request = GetInstance(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, returnPushServiceToken: true)
		performRequest(request: request, completion: completion)
	}

	func deleteInstance(applicationCode: String, pushRegistrationId: String, expiredPushRegistrationId: String, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		let request = DeleteInstance(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, expiredPushRegistrationId: expiredPushRegistrationId)
		performRequest(request: request, completion: completion)
	}
}

protocol SessionManagement {
	var sessionManager: DynamicBaseUrlHTTPSessionManager { get }
	func convertJSONToResult<Response: JSONDecodable>(request: RequestData, json: JSON?, error: NSError?) -> MMResult<Response>
	func performRequest<Response: JSONDecodable>(request: RequestData, completion: @escaping (MMResult<Response>) -> Void)
}

extension SessionManagement {
	func convertJSONToResult<Response: JSONDecodable>(request: RequestData, json: JSON?, error: NSError?) -> MMResult<Response> {
		if let error = error {
			return MMResult.Failure(error)
		} else {
			if let json = json, let response = Response(json: json) {
				return MMResult.Success(response)
			} else {
				return MMResult.Failure(nil)
			}
		}
	}
	func performRequest<Response: JSONDecodable>(request: RequestData, completion: @escaping (MMResult<Response>) -> Void) {
		sessionManager.getDataResponse(request, completion: {
            UserEventsManager.postApiErrorEvent($1)
			completion(self.convertJSONToResult(request: request, json: $0, error: $1))
		})
	}
}

protocol GeneralRemoteAPIProtocol: SessionManagement {
    func getBaseUrl(applicationCode: String, completion: @escaping (BaseUrlResult) -> Void)
    
	func sendUserSessionReport(applicationCode: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (UserSessionSendingResult) -> Void)

	func sendSeenStatus(applicationCode: String, pushRegistrationId: String?, body: RequestBody, completion: @escaping (SeenStatusSendingResult) -> Void)

	func sendMessages(applicationCode: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (MOMessageSendingResult) -> Void)

	func syncMessages(applicationCode: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (MessagesSyncResult) -> Void)

	func fetchRecentLibraryVersion(applicationCode: String, pushRegistrationId: String?, completion: @escaping (LibraryVersionResult) -> Void)

	func depersonalize(applicationCode: String, pushRegistrationId: String, pushRegistrationIdToDepersonalize: String, completion: @escaping (DepersonalizeResult) -> Void)

	func personalize(applicationCode: String, pushRegistrationId: String, body: RequestBody, forceDepersonalize: Bool, completion: @escaping (PersonalizeResult) -> Void)

	func patchUser(applicationCode: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateUserDataResult) -> Void)

	func getUser(applicationCode: String, pushRegistrationId: String, completion: @escaping (FetchUserDataResult) -> Void)

	func patchInstance(applicationCode: String, authPushRegistrationId: String, refPushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateInstanceDataResult) -> Void)

	func postInstance(applicationCode: String, body: RequestBody, completion: @escaping (FetchInstanceDataResult) -> Void)

	func patchOtherInstance(applicationCode: String, authPushRegistrationId: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateInstanceDataResult) -> Void)

	func getInstance(applicationCode: String, pushRegistrationId: String, completion: @escaping (FetchInstanceDataResult) -> Void)

	func deleteInstance(applicationCode: String, pushRegistrationId: String, expiredPushRegistrationId: String, completion: @escaping (UpdateInstanceDataResult) -> Void)

	func sendCustomEvent(applicationCode: String, pushRegistrationId: String, validate: Bool, body: RequestBody, completion: @escaping (CustomEventResult) -> Void)
}
