//
//  RemoteAPIProvider.swift
//
//  Created by Andrey K. on 26/11/2016.
//
//

import Foundation

class RemoteAPIProvider {
	var versionFetchingQueue: RemoteAPIQueue
	var registrationQueue: RemoteAPIQueue
	var messageSyncQueue: RemoteAPIQueue
	var seenStatusQueue: RemoteAPIQueue
	
	init() {
		registrationQueue = RemoteAPIQueue()
		seenStatusQueue = RemoteAPIQueue()
		messageSyncQueue = RemoteAPIQueue()
		versionFetchingQueue = RemoteAPIQueue()
	}

	func sendSeenStatus(applicationCode: String, pushRegistrationId: String?, seenList: [SeenData], completion: @escaping (SeenStatusSendingResult) -> Void) {
		let request = SeenStatusSendingRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, seenList: seenList)
		seenStatusQueue.perform(request: request, completion: completion)
	}
	
	func sendMessages(applicationCode: String, pushRegistrationId: String, messages: [MOMessage], completion: @escaping (MOMessageSendingResult) -> Void) {
		let request = MOMessageSendingRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, messages: messages)
		messageSyncQueue.perform(request: request, completion: completion)
	}
	
	func syncMessages(applicationCode: String, pushRegistrationId: String, archiveMsgIds: [String]?, dlrMsgIds: [String]?, completion: @escaping (MessagesSyncResult) -> Void) {
		let request = MessagesSyncRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, archiveMsgIds: archiveMsgIds, dlrMsgIds: dlrMsgIds)
		messageSyncQueue.perform(request: request, exclusively: true, completion: completion)
	}

	func fetchRecentLibraryVersion(applicationCode: String, pushRegistrationId: String?, completion: @escaping (LibraryVersionResult) -> Void) {
		let request = LibraryVersionRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId)
		versionFetchingQueue.perform(request: request, completion: completion)
	}
	
//new api
	func depersonalize(applicationCode: String, pushRegistrationId: String, pushRegistrationIdToDepersonalize: String, completion: @escaping (DepersonalizeResult) -> Void) {
		registrationQueue.perform(request: PostDepersonalize(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, pushRegistrationIdToDepersonalize: pushRegistrationIdToDepersonalize), completion: completion)
	}

	func personalize(applicationCode: String, pushRegistrationId: String, body: RequestBody, forceDepersonalize: Bool, completion: @escaping (PersonalizeResult) -> Void) {
		let r = PostPersonalize(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body, forceDepersonalize: forceDepersonalize)
		registrationQueue.perform(request: r, completion: completion)
	}

	func patchUser(applicationCode: String, pushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateUserDataResult) -> Void) {
		if let request = PatchUser(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, body: body, returnInstance: false, returnPushServiceToken: false) {
			registrationQueue.perform(request: request, completion: completion)
		} else {
			completion(.Cancel)
		}
	}

	func getUser(applicationCode: String, pushRegistrationId: String, completion: @escaping (FetchUserDataResult) -> Void) {
		let request = GetUser(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, returnInstance: true, returnPushServiceToken: false)
		registrationQueue.perform(request: request, completion: completion)
	}

	func patchInstance(applicationCode: String, authPushRegistrationId: String, refPushRegistrationId: String, body: RequestBody, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		if let request = PatchInstance(applicationCode: applicationCode, authPushRegistrationId: authPushRegistrationId, refPushRegistrationId: refPushRegistrationId, body: body, returnPushServiceToken: false) {
			registrationQueue.perform(request: request, completion: completion)
		} else {
			completion(.Cancel)
		}
	}

	func postInstance(applicationCode: String, body: RequestBody, completion: @escaping (FetchInstanceDataResult) -> Void) {
		if let request = PostInstance(applicationCode: applicationCode, body: body, returnPushServiceToken: false) {
			registrationQueue.perform(request: request, completion: completion)
		} else {
			completion(.Cancel)
		}
	}

	func getInstance(applicationCode: String, pushRegistrationId: String, completion: @escaping (FetchInstanceDataResult) -> Void) {
		let request = GetInstance(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, returnPushServiceToken: false)
		registrationQueue.perform(request: request, completion: completion)
	}

	func deleteInstance(applicationCode: String, pushRegistrationId: String, expiredPushRegistrationId: String, completion: @escaping (UpdateInstanceDataResult) -> Void) {
		let request = DeleteInstance(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, expiredPushRegistrationId: expiredPushRegistrationId)
		registrationQueue.perform(request: request, completion: completion)
	}
}
