//
//  RemoteAPIProvider.swift
//
//  Created by Andrey K. on 26/11/2016.
//
//

import Foundation

class RemoteAPIProvider {
	internal(set) var versionFetchingQueue: RemoteAPIQueue
	internal(set) var registrationQueue: RemoteAPIQueue
	internal(set) var messageSyncQueue: RemoteAPIQueue
	internal(set) var seenStatusQueue: RemoteAPIQueue
	
	init() {
		registrationQueue = RemoteAPIQueue()
		seenStatusQueue = RemoteAPIQueue()
		messageSyncQueue = RemoteAPIQueue()
		versionFetchingQueue = RemoteAPIQueue()
	}
	
	func syncRegistration(applicationCode: String, pushRegistrationId: String?, deviceToken: String, isEnabled: Bool?, expiredInternalId: String?, completion: @escaping (RegistrationResult) -> Void) {
		let request = RegistrationRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, deviceToken: deviceToken, isEnabled: isEnabled, expiredInternalId: expiredInternalId)
		registrationQueue.perform(request: request, completion: completion)
	}
	
	func getInstance(applicationCode: String, pushRegistrationId: String, completion: @escaping (GetInstanceResult) -> Void) {
		registrationQueue.perform(request: GetInstanceRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId), completion: completion)
	}
	
	func putInstance(applicationCode: String, pushRegistrationId: String, isPrimaryDevice: Bool, completion: @escaping (PutInstanceResult) -> Void) {
		registrationQueue.perform(request: PutInstanceRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, isPrimary: isPrimaryDevice), completion: completion)
	}
	
	func fetchUserData(applicationCode: String, pushRegistrationId: String, externalUserId: String?, completion: @escaping (UserDataSyncResult) -> Void) {
		let request = UserDataRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, externalUserId: externalUserId)
		registrationQueue.perform(request: request, completion: completion)
	}
	
	func syncUserData(applicationCode: String, pushRegistrationId: String, externalUserId: String?, predefinedUserData: UserDataDictionary? = nil, customUserData: [String: CustomUserDataValue]? = nil, completion: @escaping (UserDataSyncResult) -> Void) {
		let request = UserDataRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, externalUserId: externalUserId, predefinedUserData: predefinedUserData, customUserData: customUserData)
		registrationQueue.perform(request: request, completion: completion)
	}
	
	func syncSystemData(applicationCode: String, pushRegistrationId: String, systemData: SystemData, completion: @escaping (SystemDataSyncResult) -> Void) {
		let request = SystemDataSyncRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, systemData: systemData)
		registrationQueue.perform(request: request, completion: completion)
	}
	
	func sendSeenStatus(applicationCode: String, pushRegistrationId: String?, seenList: [SeenData], completion: @escaping (SeenStatusSendingResult) -> Void) {
		let request = SeenStatusSendingRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, seenList: seenList)
		seenStatusQueue.perform(request: request, completion: completion)
	}
	
	func sendMessages(applicationCode: String, pushRegistrationId: String, messages: [MOMessage], completion: @escaping (MOMessageSendingResult) -> Void) {
		let request = MOMessageSendingRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, messages: messages)
		messageSyncQueue.perform(request: request, completion: completion)
	}
	
	func logout(applicationCode: String, pushRegistrationId: String, completion: @escaping (LogoutResult) -> Void) {
		registrationQueue.perform(request: LogoutRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId), completion: completion)
	}
	
	func syncMessages(applicationCode: String, pushRegistrationId: String, archiveMsgIds: [String]?, dlrMsgIds: [String]?, completion: @escaping (MessagesSyncResult) -> Void) {
		let request = MessagesSyncRequest(applicationCode: applicationCode, pushRegistrationId: pushRegistrationId, archiveMsgIds: archiveMsgIds, dlrMsgIds: dlrMsgIds)
		messageSyncQueue.perform(request: request, exclusively: true, completion: completion)
	}

	func fetchRecentLibraryVersion(completion: @escaping (LibraryVersionResult) -> Void) {
		let request = LibraryVersionRequest()
		versionFetchingQueue.perform(request: request, completion: completion)
	}
}
