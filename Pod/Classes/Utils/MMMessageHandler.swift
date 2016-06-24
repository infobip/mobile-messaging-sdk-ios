//
//  MMMessageHandler.swift
//  MobileMessaging
//
//  Created by Andrey K. on 24/02/16.
//  
//

import Foundation
import CoreData

final class MMMessageHandler {
	lazy var messageHandlingQueue = OperationQueue.newSerialQueue

	var storage: MMCoreDataStorage
    convenience init(storage: MMCoreDataStorage, baseURL: String, applicationCode: String) {
        let remoteAPI = MMRemoteAPIQueue(baseURL: baseURL, applicationCode: applicationCode)
        let seenSenderRemoteAPI = MMRemoteAPIQueue(baseURL: baseURL, applicationCode: applicationCode)
        self.init(storage: storage, remoteApi: remoteAPI, seenSenderRemoteAPI: seenSenderRemoteAPI)
    }
    
    init(storage: MMCoreDataStorage, remoteApi: MMRemoteAPIQueue, seenSenderRemoteAPI: MMRemoteAPIQueue) {
        self.messageSyncRemoteAPI = remoteApi
        self.seenSenderRemoteAPI = seenSenderRemoteAPI
		self.storage = storage
        self.evictOldMessages()
    }

    //MARK: Intenal
	func handleAPNSMessage(userInfo: [NSObject : AnyObject], newMessageReceivedCallback: ([NSObject : AnyObject] -> Void)? = nil, completion: (NSError? -> Void)? = nil) {
		self.messageHandlingQueue.addOperation(MessageHandlingOperation(userInfos: [userInfo], messagesOrigin: .APNS, context: self.storage.newPrivateContext(), remoteAPIQueue: self.messageSyncRemoteAPI, newMessageReceivedCallback: newMessageReceivedCallback, finishBlock: completion))
	}
	
	func syncWithServer(completion: (NSError? -> Void)? = nil) {
		self.messageHandlingQueue.addOperation(MessagesSyncOperation(context: self.storage.newPrivateContext(), remoteAPIQueue: self.messageSyncRemoteAPI, finishBlock: completion))
	}
	
	func evictOldMessages(messageAge: NSTimeInterval? = nil, completion:(() -> Void)? = nil) {
		self.messageHandlingQueue.addOperation(MessagesEvictionOperation(context: self.storage.newPrivateContext(), messageMaximumAge: messageAge, finishBlock: completion))
    }
	
    func setSeen(messageIds: [String], completion: (MMSeenMessagesResult -> Void)? = nil) {
		self.messageHandlingQueue.addOperation(SetSeenOperation(messageIds: messageIds, context: self.storage.newPrivateContext(), remoteAPIQueue: self.seenSenderRemoteAPI, finishBlock: completion))
    }
	
	//MARK: Private
    private var messageSyncRemoteAPI: MMRemoteAPIQueue
    private var seenSenderRemoteAPI: MMRemoteAPIQueue
}