//
//  RemoteAPIManager.swift
//
//  Created by Andrey K. on 26/11/2016.
//
//

import Foundation

class RemoteAPIManager {
	internal(set) var versionFetchingQueue: MMRemoteAPIQueue
	internal(set) var registrationQueue: MMRemoteAPIQueue
	internal(set) var messageSyncQueue: MMRemoteAPIQueue
	internal(set) var seenStatusQueue: MMRemoteAPIQueue
	internal(set) var geofencingServiceQueue: MMRemoteAPIQueue
	
	init(baseUrl: String, applicationCode: String) {
		registrationQueue = MMRemoteAPIQueue(baseURL: baseUrl, applicationCode: applicationCode)
		seenStatusQueue = MMRemoteAPIQueue(baseURL: baseUrl, applicationCode: applicationCode)
		messageSyncQueue = MMRemoteAPIQueue(baseURL: baseUrl, applicationCode: applicationCode)
		geofencingServiceQueue = MMRemoteAPIQueue(baseURL: baseUrl, applicationCode: applicationCode)
		versionFetchingQueue = MMRemoteAPIQueue(baseURL: baseUrl, applicationCode: applicationCode)
	}
	
	func syncRegistration(internalId: String?, deviceToken: String, isEnabled: Bool?, completion: @escaping (RegistrationResult) -> Void) {
		let request = RegistrationRequest(deviceToken: deviceToken, internalId: internalId, isEnabled: isEnabled)
		registrationQueue.perform(request: request, completion: completion)
	}
	
	func fetchUserData(internalUserId: String, externalUserId: String?, completion: @escaping (UserDataSyncResult) -> Void) {
		let request = UserDataRequest(internalUserId: internalUserId, externalUserId: externalUserId)
		registrationQueue.perform(request: request, completion: completion)
	}
	
	func syncUserData(internalUserId: String, externalUserId: String?, predefinedUserData: UserDataDictionary? = nil, customUserData: [String: CustomUserDataValue]? = nil, completion: @escaping (UserDataSyncResult) -> Void) {
		let request = UserDataRequest(internalUserId: internalUserId, externalUserId: externalUserId, predefinedUserData: predefinedUserData, customUserData: customUserData)
		registrationQueue.perform(request: request, completion: completion)
	}
	
	func syncSystemData(internalUserId: String, systemData: MMSystemData, completion: @escaping (SystemDataSyncResult) -> Void) {
		let request = SystemDataSyncRequest(internalUserId: internalUserId, systemData: systemData)
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
	
	func syncMessages(internalId: String, archiveMsgIds: [String]?, dlrMsgIds: [String]?, completion: @escaping (MessagesSyncResult) -> Void) {
		let request = MessagesSyncRequest(internalId: internalId, archiveMsgIds: archiveMsgIds, dlrMsgIds: dlrMsgIds)
		messageSyncQueue.perform(request: request, exclusively: true, completion: completion)
	}
	
	func sendGeoEventReports(eventsDataList: [GeoEventReportData], completion: @escaping (MMGeoEventReportingResult) -> Void) {
		let request = GeoEventReportingRequest(eventsDataList: eventsDataList)
		geofencingServiceQueue.perform(request: request, completion: completion)
	}
	
	func fetchRecentLibraryVersion(completion: @escaping (LibraryVersionResult) -> Void) {
		let request = LibraryVersionRequest()
		versionFetchingQueue.perform(request: request, completion: completion)
	}
}
