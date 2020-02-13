//
//  RemoteAPIProvider.swift
//
//  Created by Andrey K. on 26/11/2016.
//
//

import Foundation

protocol GeneralRemoteAPIProtocol: SessionManagement {
	func sendSeenStatus(applicationCode: String, pushRegistrationId: String?, seenList: [SeenData], completion: @escaping (SeenStatusSendingResult) -> Void)

	func sendMessages(applicationCode: String, pushRegistrationId: String, messages: [MOMessage], completion: @escaping (MOMessageSendingResult) -> Void)

	func syncMessages(applicationCode: String, pushRegistrationId: String, archiveMsgIds: [String]?, dlrMsgIds: [String]?, completion: @escaping (MessagesSyncResult) -> Void)

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
}

protocol SessionManagement {
	var sessionManager: DynamicBaseUrlHTTPSessionManager { get }
	func convertJSONToResult<R: RequestData>(request: R, json: JSON?, error: NSError?) -> MMResult<R.ResponseType>
	func performRequest<R: RequestData>(request: R, completion: @escaping (MMResult<R.ResponseType>) -> Void)
}

extension SessionManagement {
	func convertJSONToResult<R: RequestData>(request: R, json: JSON?, error: NSError?) -> MMResult<R.ResponseType> {
		if let error = error {
			return MMResult.Failure(error)
		} else {
			if let json = json, let response = R.ResponseType(json: json) {
				return MMResult.Success(response)
			} else {
				return MMResult.Failure(NSError(type: .UnknownResponseFormat))
			}
		}
	}
	func performRequest<R: RequestData>(request: R, completion: @escaping (MMResult<R.ResponseType>) -> Void) {
		sessionManager.sendRequest(request, completion: {
			completion(self.convertJSONToResult(request: request, json: $0, error: $1))
		})
	}
}

class RemoteAPIProvider: GeneralRemoteAPIProtocol {
	var sessionManager: DynamicBaseUrlHTTPSessionManager

	init(sessionManager: DynamicBaseUrlHTTPSessionManager) {
		self.sessionManager = sessionManager
	}

	func sendSeenStatus(applicationCode: String, pushRegistrationId: String?, seenList: [SeenData], completion: @escaping (SeenStatusSendingResult) -> Void) {
		let request = SeenStatusSendingRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, seenList: seenList)
		performRequest(request: request, completion: completion)
	}
	
	func sendMessages(applicationCode: String, pushRegistrationId: String, messages: [MOMessage], completion: @escaping (MOMessageSendingResult) -> Void) {
		let request = MOMessageSendingRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, messages: messages)
		performRequest(request: request, completion: completion)
	}
	
	func syncMessages(applicationCode: String, pushRegistrationId: String, archiveMsgIds: [String]?, dlrMsgIds: [String]?, completion: @escaping (MessagesSyncResult) -> Void) {
		let request = MessagesSyncRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, archiveMsgIds: archiveMsgIds, dlrMsgIds: dlrMsgIds)
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
