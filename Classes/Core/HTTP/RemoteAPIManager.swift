//
//  RemoteAPIManager.swift
//
//  Created by Andrey K. on 26/11/2016.
//
//

import Foundation

class RemoteAPIManager {
	internal(set) var versionFetchingQueue: RemoteAPIQueue
	internal(set) var registrationQueue: RemoteAPIQueue
	internal(set) var messageSyncQueue: RemoteAPIQueue
	internal(set) var seenStatusQueue: RemoteAPIQueue
	
	init(baseUrl: String, applicationCode: String, mmContext: MobileMessaging) {
		registrationQueue = RemoteAPIQueue(mmContext: mmContext, baseURL: baseUrl, applicationCode: applicationCode)
		seenStatusQueue = RemoteAPIQueue(mmContext: mmContext, baseURL: baseUrl, applicationCode: applicationCode)
		messageSyncQueue = RemoteAPIQueue(mmContext: mmContext, baseURL: baseUrl, applicationCode: applicationCode)
		versionFetchingQueue = RemoteAPIQueue(mmContext: mmContext, baseURL: baseUrl, applicationCode: applicationCode)
	}
	
	func syncRegistration(deviceToken: String, isEnabled: Bool?, expiredInternalId: String?, completion: @escaping (RegistrationResult) -> Void) {
		let request = RegistrationRequest(deviceToken: deviceToken, isEnabled: isEnabled, expiredInternalId: expiredInternalId)
		registrationQueue.perform(request: request, completion: completion)
	}
	
	func fetchUserData(externalUserId: String?, completion: @escaping (UserDataSyncResult) -> Void) {
		let request = UserDataRequest(externalUserId: externalUserId)
		registrationQueue.perform(request: request, completion: completion)
	}
	
	func syncUserData(externalUserId: String?, predefinedUserData: UserDataDictionary? = nil, customUserData: [String: CustomUserDataValue]? = nil, completion: @escaping (UserDataSyncResult) -> Void) {
		let request = UserDataRequest(externalUserId: externalUserId, predefinedUserData: predefinedUserData, customUserData: customUserData)
		registrationQueue.perform(request: request, completion: completion)
	}
	
	func syncSystemData(systemData: SystemData, completion: @escaping (SystemDataSyncResult) -> Void) {
		let request = SystemDataSyncRequest(systemData: systemData)
		registrationQueue.perform(request: request, completion: completion)
	}
	
	func sendSeenStatus(seenList: [SeenData], completion: @escaping (SeenStatusSendingResult) -> Void) {
		let request = SeenStatusSendingRequest(seenList: seenList)
		seenStatusQueue.perform(request: request, completion: completion)
	}
	
	func sendMessages(internalUserId: String, messages: [MOMessage], completion: @escaping (MOMessageSendingResult) -> Void) {
		let request = MOMessageSendingRequest(internalUserId: internalUserId, messages: messages)
		messageSyncQueue.perform(request: request, completion: completion)
	}
	
	func syncMessages(archiveMsgIds: [String]?, dlrMsgIds: [String]?, completion: @escaping (MessagesSyncResult) -> Void) {
		let request = MessagesSyncRequest(archiveMsgIds: archiveMsgIds, dlrMsgIds: dlrMsgIds)
		messageSyncQueue.perform(request: request, exclusively: true, completion: completion)
	}

	func fetchRecentLibraryVersion(completion: @escaping (LibraryVersionResult) -> Void) {
		let request = LibraryVersionRequest()
		versionFetchingQueue.perform(request: request, completion: completion)
	}
}
