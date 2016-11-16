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
	lazy var messageHandlingQueue = OperationQueue.mm_newSerialQueue
	lazy var messageSendingQueue = OperationQueue()
	lazy var seenPostponer = MMPostponer(executionQueue: DispatchQueue.main)
	
	deinit {
		messageHandlingQueue.cancelAllOperations()
	}
	
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
	func handleAPNSMessage(_ userInfo: APNSPayload, applicationState: UIApplicationState, newMessageReceivedCallback: ((APNSPayload) -> Void)? = nil, completion: ((NSError?) -> Void)? = nil) {
		if let msg = MMMessageFactory.makeMessage(with: userInfo, createdDate: Date()) {
			self.messageHandlingQueue.addOperation(MessageHandlingOperation(messagesToHandle: [msg], messagesDeliveryMethod: .push, context: self.storage.newPrivateContext(), remoteAPIQueue: self.messageSyncRemoteAPI, messageHandler: MobileMessaging.messageHandling, applicationState: applicationState, finishBlock: completion))
		} else {
			MMLogError("Error while converting payload:\n\(userInfo)\nto MMMessage")
		}
	}
	
	func syncWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		self.messageHandlingQueue.addOperation(MessagesSyncOperation(context: self.storage.newPrivateContext(), remoteAPIQueue: self.messageSyncRemoteAPI, finishBlock: completion))
	}
	
	func evictOldMessages(_ messageAge: TimeInterval? = nil, completion:((Void) -> Void)? = nil) {
		self.messageHandlingQueue.addOperation(MessagesEvictionOperation(context: self.storage.newPrivateContext(), messageMaximumAge: messageAge, finishBlock: completion))
    }
	
	
    func setSeen(_ messageIds: [String], completion: ((MMSeenMessagesResult) -> Void)? = nil) {
		self.messageHandlingQueue.addOperation(SeenStatusPersistingOperation(messageIds: messageIds, context: self.storage.newPrivateContext()))
		seenPostponer.postponeBlock() {
			self.messageHandlingQueue.addOperation(SeenStatusSendingOperation(context: self.storage.newPrivateContext(), remoteAPIQueue: self.seenSenderRemoteAPI, finishBlock: completion))
		}
    }
	
	func sendMessages(_ messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		self.messageSendingQueue.addOperation(MessagePostingOperation(messages: messages, context: self.storage.newPrivateContext(), remoteAPIQueue: self.messageSyncRemoteAPI, finishBlock: { (result: MMMOMessageResult) in
			
			completion?(result.value?.messages, result.error)
		}))
	}
	
	//MARK: Private
    private var messageSyncRemoteAPI: MMRemoteAPIQueue
    private var seenSenderRemoteAPI: MMRemoteAPIQueue
}
