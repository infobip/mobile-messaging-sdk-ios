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
	
	init(mmContext: MobileMessaging) {
		registrationQueue = RemoteAPIQueue(mmContext: mmContext)
		seenStatusQueue = RemoteAPIQueue(mmContext: mmContext)
		messageSyncQueue = RemoteAPIQueue(mmContext: mmContext)
		versionFetchingQueue = RemoteAPIQueue(mmContext: mmContext)
	}
	
	func syncRegistration(deviceToken: String, isEnabled: Bool?, expiredInternalId: String?, completion: @escaping (RegistrationResult) -> Void) {
		let request = RegistrationRequest(deviceToken: deviceToken, isEnabled: isEnabled, expiredInternalId: expiredInternalId)
		registrationQueue.perform(request: request, completion: completion)
	}
	
	func getInstance(completion: @escaping (GetInstanceResult) -> Void) {
		registrationQueue.perform(request: GetInstanceRequest(), completion: completion)
	}
	
	func putInstance(isPrimaryDevice: Bool, completion: @escaping (PutInstanceResult) -> Void) {
		registrationQueue.perform(request: PutInstanceRequest(isPrimary: isPrimaryDevice), completion: completion)
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
	
	func logout(completion: @escaping (LogoutResult) -> Void) {
		registrationQueue.perform(request: LogoutRequest(), completion: completion)
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
