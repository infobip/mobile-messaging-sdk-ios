//
//  MMMessageHandler.swift
//  MobileMessaging
//
//  Created by Andrey K. on 24/02/16.
//  
//

import Foundation

class MMMessageHandler : MMStoringService {
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
		handleMessages([userInfo], newMessageReceivedCallback: newMessageReceivedCallback, completion: completion)
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
	
	func evictOldMessages(completion:(() -> Void)? = nil) {
		messageHandlingQueue.addOperationWithBlock { 
			self.storageContext.performBlockAndWait {
				let dateToCompare = NSDate().dateByAddingTimeInterval(-MMMessageHandler.kEntityExpirationPeriod)
				
				MessageManagedObject.MR_deleteAllMatchingPredicate(NSPredicate(format: "creationDate <= %@", dateToCompare), inContext: self.storageContext)
				self.save()
				completion?()
			}
		}
    }
	
    func setSeen(messageIds: [String], completion: (MMSeenMessagesResult -> Void)? = nil) {
		messageHandlingQueue.addOperation(SendSeenOperation(messageIds: messageIds, context: storageContext, remoteAPIQueue: seenSenderRemoteAPI, finishBlock: completion))
    }
	
	//MARK: Private
	private func handleMessages(userInfos: [[NSObject : AnyObject]], newMessageReceivedCallback: (() -> Void)? = nil, completion: ((NSError?) -> Void)? = nil) {
		messageHandlingQueue.addOperation(MessageHandlingOperation(userInfos: userInfos, context: storageContext, remoteAPIQueue: messageSyncRemoteAPI, newMessageReceivedCallback: newMessageReceivedCallback, finishBlock: completion))
	}
	
    private var messageSyncRemoteAPI: MMRemoteAPIQueue
    private var seenSenderRemoteAPI: MMRemoteAPIQueue
    
    private static let kEntityExpirationPeriod: NSTimeInterval = 7 * 24 * 60 * 60; //one week
}