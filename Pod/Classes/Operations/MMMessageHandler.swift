//
//  MMMessageHandler.swift
//  MobileMessaging
//
//  Created by Andrey K. on 24/02/16.
//  
//

import Foundation
import CoreData

protocol MobileMessagingService {
	var isRunning: Bool { get }
	func start(_ completion: ((Bool) -> Void)?)
	func stop(_ completion: ((Bool) -> Void)?)
}

final class MMMessageHandler: MobileMessagingService {
	var isRunning: Bool = true
	func start(_ completion: ((Bool) -> Void)? = nil) {
		isRunning = true
		completion?(true)
	}
	func stop(_ completion: ((Bool) -> Void)? = nil) {
		isRunning = false
		completion?(true)
	}
	

	lazy var messageHandlingQueue = MMOperationQueue.newSerialQueue
	lazy var messageSendingQueue = MMOperationQueue()
	lazy var messageSyncQueue = MMOperationQueue.newSerialQueue

	lazy var seenPostponer = MMPostponer(executionQueue: DispatchQueue.main)
	
	deinit {
		messageHandlingQueue.cancelAllOperations()
	}
	
	let storage: MMCoreDataStorage
    
	init(storage: MMCoreDataStorage) {
		self.storage = storage
        self.evictOldMessages()
    }

    //MARK: Intenal
	func handleAPNSMessage(_ userInfo: APNSPayload, applicationState: UIApplicationState, newMessageReceivedCallback: ((APNSPayload) -> Void)? = nil, completion: ((NSError?) -> Void)? = nil) {
		guard isRunning == true else {
			completion?(nil)
			return
		}
		if let msg = MMMessageFactory.makeMessage(with: userInfo, createdDate: Date()) {
			
			messageHandlingQueue.addOperation(MessageHandlingOperation(messagesToHandle: [msg], messagesDeliveryMethod: .push, context: storage.newPrivateContext(), messageHandler: MobileMessaging.messageHandling, applicationState: applicationState, finishBlock: { error in
				
				self.messageSyncQueue.addOperation(MessageFetchingOperation(context: self.storage.newPrivateContext(), finishBlock: { result in
					completion?(result.error)
				}))
			}))
			
		} else {
			MMLogError("Error while converting payload:\n\(userInfo)\nto MMMessage")
			completion?(NSError.init(type: .UnknownError))
		}
	}
	
	func syncWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		guard isRunning == true else {
			completion?(nil)
			return
		}
		messageSyncQueue.addOperation(MessagesSyncOperation(context: storage.newPrivateContext(), finishBlock: completion))
	}
	
	func evictOldMessages(_ messageAge: TimeInterval? = nil, completion:((Void) -> Void)? = nil) {
		messageHandlingQueue.addOperation(MessagesEvictionOperation(context: storage.newPrivateContext(), messageMaximumAge: messageAge, finishBlock: completion))
    }
	
    func setSeen(_ messageIds: [String], completion: ((SeenStatusSendingResult) -> Void)? = nil) {
		messageHandlingQueue.addOperation(SeenStatusPersistingOperation(messageIds: messageIds, context: storage.newPrivateContext()))
		seenPostponer.postponeBlock() {
			self.messageSyncQueue.addOperation(SeenStatusSendingOperation(context: self.storage.newPrivateContext(), finishBlock: completion))
		}
    }
	
	func sendMessages(_ messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		messageSendingQueue.addOperation(MessagePostingOperation(messages: messages, context: storage.newPrivateContext(), finishBlock: { (result: MOMessageSendingResult) in
			completion?(result.value?.messages, result.error)
		}))
	}
}
