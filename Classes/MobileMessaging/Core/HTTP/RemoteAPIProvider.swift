//
//  RemoteAPIProvider.swift
//
//  Created by Andrey K. on 26/11/2016.
//
//

import Foundation

public class RemoteAPIProvider: SessionManagement {
    public var sessionManager: DynamicBaseUrlHTTPSessionManager

	init(sessionManager: DynamicBaseUrlHTTPSessionManager) {
		self.sessionManager = sessionManager
	}
    
    func getBaseUrl(applicationCode: String, queue: DispatchQueue, completion: @escaping (BaseUrlResult) -> Void) {
        let request = BaseUrlRequest(applicationCode: applicationCode)
        performRequest(request: request, queue: queue, completion: completion)
    }

	func sendCustomEvent(applicationCode: String, pushRegistrationId: String, validate: Bool, body: RequestBody, queue: DispatchQueue, completion: @escaping (CustomEventResult) -> Void) {
		let request = PostCustomEvent(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, validate: validate, requestBody: body)
		performRequest(request: request, queue: queue, completion: completion)
	}

	public func sendSeenStatus(applicationCode: String, pushRegistrationId: String?, body: RequestBody, queue: DispatchQueue, completion: @escaping (SeenStatusSendingResult) -> Void) {
		let request = SeenStatusSendingRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body)
		performRequest(request: request, queue: queue, completion: completion)
	}

	func sendUserSessionReport(applicationCode: String, pushRegistrationId: String, body: RequestBody, queue: DispatchQueue, completion: @escaping (UserSessionSendingResult) -> Void) {
		let request = PostUserSession(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, requestBody: body)
		performRequest(request: request, queue: queue, completion: completion)
	}
	
	func sendMessages(applicationCode: String, pushRegistrationId: String, body: RequestBody, queue: DispatchQueue, completion: @escaping (MOMessageSendingResult) -> Void) {
		let request = MOMessageSendingRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body)
        performRequest(request: request, queue: queue, completion: completion)
	}
	
	func syncMessages(applicationCode: String, pushRegistrationId: String, body: RequestBody, queue: DispatchQueue, completion: @escaping (MessagesSyncResult) -> Void) {
		let request = MessagesSyncRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body)
        performRequest(request: request, queue: queue, completion: completion)
	}

	func fetchRecentLibraryVersion(applicationCode: String, pushRegistrationId: String?, queue: DispatchQueue, completion: @escaping (LibraryVersionResult) -> Void) {
		let request = LibraryVersionRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId)
        performRequest(request: request, queue: queue, completion: completion)
	}
	
//new api
	func depersonalize(applicationCode: String, pushRegistrationId: String, pushRegistrationIdToDepersonalize: String, queue: DispatchQueue, completion: @escaping (DepersonalizeResult) -> Void) {
		let request = PostDepersonalize(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, pushRegistrationIdToDepersonalize: pushRegistrationIdToDepersonalize)
        performRequest(request: request, queue: queue, completion: completion)
	}

	func personalize(applicationCode: String, pushRegistrationId: String, body: RequestBody, forceDepersonalize: Bool, queue: DispatchQueue, completion: @escaping (PersonalizeResult) -> Void) {
		let request = PostPersonalize(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body, forceDepersonalize: forceDepersonalize)
        performRequest(request: request, queue: queue, completion: completion)
	}

	func patchUser(applicationCode: String, pushRegistrationId: String, body: RequestBody, queue: DispatchQueue, completion: @escaping (UpdateUserDataResult) -> Void) {
		if let request = PatchUser(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body, returnInstance: false, returnPushServiceToken: false) {
            performRequest(request: request, queue: queue, completion: completion)
		} else {
			completion(.Cancel)
		}
	}

	func getUser(applicationCode: String, pushRegistrationId: String, queue: DispatchQueue, completion: @escaping (FetchUserDataResult) -> Void) {
		let request = GetUser(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, returnInstance: true, returnPushServiceToken: false)
        performRequest(request: request, queue: queue, completion: completion)
	}

	func patchInstance(applicationCode: String, authPushRegistrationId: String, refPushRegistrationId: String, body: RequestBody, queue: DispatchQueue, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		if let request = PatchInstance(applicationCode: applicationCode, authPushRegistrationId: authPushRegistrationId, refPushRegistrationId: refPushRegistrationId, body: body, returnPushServiceToken: false) {
            performRequest(request: request, queue: queue, completion: completion)
		} else {
			completion(.Cancel)
		}
	}

	func postInstance(applicationCode: String, body: RequestBody, queue: DispatchQueue, completion: @escaping (FetchInstanceDataResult) -> Void) {
		if let request = PostInstance(applicationCode: applicationCode, body: body, returnPushServiceToken: true) {
            performRequest(request: request, queue: queue, completion: completion)
		} else {
			completion(.Cancel)
		}
	}

	func patchOtherInstance(applicationCode: String, authPushRegistrationId: String, pushRegistrationId: String, body: RequestBody, queue: DispatchQueue, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		if let request = PatchInstance(applicationCode: applicationCode, authPushRegistrationId: authPushRegistrationId, refPushRegistrationId: pushRegistrationId, body: body, returnPushServiceToken: false) {
            performRequest(request: request, queue: queue, completion: completion)
		} else {
			completion(.Cancel)
		}
	}

	func getInstance(applicationCode: String, pushRegistrationId: String, queue: DispatchQueue, completion: @escaping (FetchInstanceDataResult) -> Void) {
		let request = GetInstance(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, returnPushServiceToken: true)
        performRequest(request: request, queue: queue, completion: completion)
	}

	func deleteInstance(applicationCode: String, pushRegistrationId: String, expiredPushRegistrationId: String, queue: DispatchQueue, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		let request = DeleteInstance(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, expiredPushRegistrationId: expiredPushRegistrationId)
        performRequest(request: request, queue: queue, completion: completion)
	}
}

public protocol SessionManagement {
	var sessionManager: DynamicBaseUrlHTTPSessionManager { get }
	func convertJSONToResult<Response: JSONDecodable>(request: RequestData, json: JSON?, error: NSError?) -> MMResult<Response>
	func performRequest<Response: JSONDecodable>(request: RequestData, queue: DispatchQueue, completion: @escaping (MMResult<Response>) -> Void)
}

extension SessionManagement {
    public func convertJSONToResult<Response: JSONDecodable>(request: RequestData, json: JSON?, error: NSError?) -> MMResult<Response> {
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
    public func performRequest<Response: JSONDecodable>(request: RequestData, queue: DispatchQueue, completion: @escaping (MMResult<Response>) -> Void) {
        sessionManager.getDataResponse(request, queue: queue, completion: {
            UserEventsManager.postApiErrorEvent($1)
			completion(self.convertJSONToResult(request: request, json: $0, error: $1))
		})
	}
}
