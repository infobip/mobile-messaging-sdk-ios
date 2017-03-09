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
	let mmContext: MobileMessaging
    
	init(storage: MMCoreDataStorage, mmContext: MobileMessaging) {
		self.storage = storage
		self.mmContext = mmContext
        self.evictOldMessages()
    }

    //MARK: Intenal
	func generateAndHandleGeoVirtualMessages(withDatasource ds: [MessageId: MMGeoMessage], completion: ((Void) -> Void)?) {
		guard !ds.isEmpty else {
			completion?()
			return
		}
		
		let virtualMessages = ds.reduce([MTMessage]()) { (result, kv: (mId: MessageId, campaign: MMGeoMessage)) -> [MTMessage] in
			if let mtMessage = MTMessage.make(fromGeoMessage: kv.campaign, messageId: kv.mId) {
				return result + [mtMessage]
			}
			return result
		}

		handleMTMessages(virtualMessages, completion: { _ in
			completion?()
		})
	}
	
	func handleAPNSMessage(_ userInfo: APNSPayload, completion: ((NSError?) -> Void)? = nil) {
		guard isRunning == true else {
			completion?(nil)
			return
		}
		if let msg = MMMessageFactory.makeMessage(with: userInfo, createdDate: Date()) {

			handleMTMessages([msg], completion: completion)

		} else {
			MMLogError("Error while converting payload:\n\(userInfo)\nto MMMessage")
			completion?(NSError.init(type: .UnknownError))
		}
	}
	
	func handleMTMessages(_ messages: [MTMessage], completion: ((NSError?) -> Void)? = nil) {
		guard isRunning == true, !messages.isEmpty else {
			completion?(nil)
			return
		}
		
		messageHandlingQueue.addOperation(MessageHandlingOperation(messagesToHandle: messages, context: storage.newPrivateContext(), messageHandler: MobileMessaging.messageHandling, applicationState: mmContext.application.applicationState, mmContext: mmContext, finishBlock: { error in
			
			self.messageSyncQueue.addOperation(MessageFetchingOperation(context: self.storage.newPrivateContext(), mmContext: self.mmContext, finishBlock: { result in
				completion?(result.error)
			}))
		}))
	}
	
	func syncWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		guard isRunning == true else {
			completion?(nil)
			return
		}
		messageSyncQueue.addOperation(MessagesSyncOperation(context: storage.newPrivateContext(), mmContext: mmContext, finishBlock: completion))
	}
	
	func evictOldMessages(_ messageAge: TimeInterval? = nil, completion:((Void) -> Void)? = nil) {
		messageHandlingQueue.addOperation(MessagesEvictionOperation(context: storage.newPrivateContext(), messageMaximumAge: messageAge, finishBlock: completion))
    }
	
    func setSeen(_ messageIds: [String], completion: ((SeenStatusSendingResult) -> Void)? = nil) {
		guard !messageIds.isEmpty else {
			completion?(SeenStatusSendingResult.Cancel)
			return
		}
		messageHandlingQueue.addOperation(SeenStatusPersistingOperation(messageIds: messageIds, context: storage.newPrivateContext(), mmContext: mmContext))
		seenPostponer.postponeBlock() {
			self.syncSeenStatusUpdates(completion)
		}
    }
	
	func syncSeenStatusUpdates(_ completion: ((SeenStatusSendingResult) -> Void)? = nil) {
		self.messageSyncQueue.addOperation(SeenStatusSendingOperation(context: self.storage.newPrivateContext(), mmContext: mmContext, finishBlock: completion))
	}
	
	func updateOiginalPayloadsWithGeoMessages(geoSignalingMessages ds: [MessageId: MMGeoMessage], completion: ((Void) -> Void)?) {
		guard !ds.isEmpty else
		{
			completion?()
			return
		}
		
		messageHandlingQueue.addOperation({
			let ctx = self.storage.newPrivateContext()
			ctx.performAndWait {
				let messageIds = ds.map { $0.key }
				
				MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIds), context: ctx)?.forEach { messageObj in
					guard let geoMessage = ds[messageObj.messageId] else {
						return
					}
					messageObj.payload = geoMessage.originalPayload
				}
			}
			ctx.MM_saveToPersistentStoreAndWait()
			completion?()
		})
	}
	
	func updateDbMessagesCampaignFinishedState(forCampaignIds finishedCampaignIds: [String], completion: ((Void) -> Void)?) {
		guard !finishedCampaignIds.isEmpty else
		{
			completion?()
			return
		}
		
		messageHandlingQueue.addOperation({
			let ctx = self.storage.newPrivateContext()
			ctx.performAndWait {
				MessageManagedObject.MM_batchUpdate(propertiesToUpdate: ["campaignStateValue": CampaignState.Finished.rawValue], predicate: NSPredicate(format: "campaignId IN %@", finishedCampaignIds), inContext: ctx)
			}
			ctx.MM_saveToPersistentStoreAndWait()
			completion?()
		})
	}
	
	/// - parameter messageIdsMap: contains pairs of message ids generated by the sdk as a key and real message ids generated by IPCore as a vlue
	func updateSdkGeneratedTemporaryMessageIds(withMap messageIdsMap: [MessageId: MessageId], completion: ((Void) -> Void)?) {
		//if the sdk generated message id was mapped with real message id, we should update all stored messages
		let sdkMessageIds = Array(messageIdsMap.keys)
		guard !sdkMessageIds.isEmpty else
		{
			completion?()
			return
		}
		
		messageHandlingQueue.addOperation({
			let ctx = self.storage.newPrivateContext()
			ctx.performAndWait {
				MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", sdkMessageIds), context: ctx)?.forEach { messageObj in
					guard let realMessageId = messageIdsMap[messageObj.messageId] else {
						return
					}
					messageObj.messageId = realMessageId
				}
			}
			ctx.MM_saveToPersistentStoreAndWait()
			completion?()
		})
	}
	
	func sendMessages(_ messages: [MOMessage], completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		messageSendingQueue.addOperation(MessagePostingOperation(messages: messages, context: storage.newPrivateContext(), mmContext: mmContext, finishBlock: { (result: MOMessageSendingResult) in
			completion?(result.value?.messages, result.error)
		}))
	}
}
