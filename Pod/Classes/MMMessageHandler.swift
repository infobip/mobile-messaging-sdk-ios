//
//  MMMessageHandler.swift
//  MobileMessaging
//
//  Created by Andrey K. on 24/02/16.
//  
//

import Foundation

final class MMMessageHandler : MMStoringService {
	lazy var messageHandlingQueue = OperationQueue.newSerialQueue
	lazy var synchronizationQueue = OperationQueue.newSerialQueue
	
    convenience init(storage: MMCoreDataStorage, baseURL: String, applicationCode: String) {
        let remoteAPI = MMRemoteAPIQueue(baseURL: baseURL, applicationCode: applicationCode)
        let seenSenderRemoteAPI = MMRemoteAPIQueue(baseURL: baseURL, applicationCode: applicationCode)
        self.init(storage: storage, remoteApi: remoteAPI, seenSenderRemoteAPI: seenSenderRemoteAPI)
    }
    
    init(storage: MMCoreDataStorage, remoteApi: MMRemoteAPIQueue, seenSenderRemoteAPI: MMRemoteAPIQueue) {
        self.messageSyncRemoteAPI = remoteApi
        self.seenSenderRemoteAPI = seenSenderRemoteAPI
        super.init(storage: storage)
        self.evictOldMessages()
    }

    //MARK: Intenal
	func handleMessage(userInfo: [NSObject : AnyObject], newMessageReceivedCallback: (() -> Void)? = nil, completion: ((NSError?) -> Void)? = nil) {
		resetMessageHandlingContext()
		messageHandlingQueue.addOperation(MessageHandlingOperation(userInfos: [userInfo], context: storageContext, remoteAPIQueue: messageSyncRemoteAPI, newMessageReceivedCallback: newMessageReceivedCallback, finishBlock: completion))
	}
	
	func syncWithServer(completion: (NSError? -> Void)? = nil) {
		do {
			let ctx = try storage.newParallelContext()
			synchronizationQueue.addOperation(MessagesSyncOperation(context: ctx, remoteAPIQueue: messageSyncRemoteAPI, finishBlock: completion))
		} catch let error as NSError {
			completion?(error)
		} catch let error as MMInternalErrorType {
			completion?(NSError(type: error))
		}
	}
	
	func evictOldMessages(messageAge: NSTimeInterval? = nil, completion:(() -> Void)? = nil) {
		resetMessageHandlingContext()
		messageHandlingQueue.addOperation(MessagesEvictionOperation(context: storageContext, messageMaximumAge: messageAge, finishBlock: completion))
    }
	
    func setSeen(messageIds: [String], completion: (MMSeenMessagesResult -> Void)? = nil) {
		resetMessageHandlingContext()
		messageHandlingQueue.addOperation(SetSeenOperation(messageIds: messageIds, context: storageContext, remoteAPIQueue: seenSenderRemoteAPI, finishBlock: completion))
    }
	
	//MARK: Private
    private var messageSyncRemoteAPI: MMRemoteAPIQueue
    private var seenSenderRemoteAPI: MMRemoteAPIQueue
	
	func resetMessageHandlingContext() {
		storageContext.performBlockAndWait { [weak self] in
			self?.storageContext.reset()
		}
	}
}