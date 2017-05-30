//
//  MMMessageHandler.swift
//  MobileMessaging
//
//  Created by Andrey K. on 24/02/16.
//  
//

import Foundation
import CoreData

enum MessageHandlingResult {
	case newData
	case noData
	case failed(NSError?)
	
	var error: NSError? {
		switch self {
		case .noData, .newData:
			return nil
		case .failed(let error):
			return error
		}
	}
	
	var backgroundFetchResult: UIBackgroundFetchResult {
		switch self {
		case .newData: return .newData
		case .noData: return .noData
		case .failed: return .failed
		}
	}
	
	init(_ result: MessagesSyncResult) {
		switch result {
		case .Success(let value) :
			guard let messages = value.messages, !messages.isEmpty else {
				self = .noData
				return
			}
			self = .newData
		case .Failure(let error) : self = .failed(error)
		default: self = .noData
		}
	}
}

final class MMMessageHandler: MobileMessagingService {
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
		self.registerSelfAsSubservice(of: mmContext)
    }

    //MARK: Intenal	
	func handleAPNSMessage(_ userInfo: APNSPayload, completion: ((MessageHandlingResult) -> Void)? = nil) {
		guard isRunning == true else {
			completion?(.noData)
			return
		}

		if let msg = MTMessage(payload: userInfo, createdDate: MobileMessaging.date.now) {
			handleMTMessages([msg], notificationTapped: MMMessageHandler.isNotificationTapped(msg, applicationState: mmContext.application.applicationState),completion: completion)
		} else {
			MMLogError("Error while converting payload:\n\(userInfo)\nto MMMessage")
			completion?(.failed(NSError.init(type: .UnknownError)))
		}
	}
	
	@available(iOS 10.0, *)
	func handleStorageFromNotificationServiceExtensionGroupContainer() {
		guard let mm = MobileMessaging.sharedInstance, let messages = mm.sharedNotificationExtensionStorage?.retrieveMessages() else
		{
			return
		}
		handleMTMessages(messages, notificationTapped: false, completion: nil)
	}
	
	func handleMTMessages(_ messages: [MTMessage], notificationTapped: Bool = false, completion: ((MessageHandlingResult) -> Void)? = nil) {
		guard isRunning == true, !messages.isEmpty else {
			completion?(.noData)
			return
		}
		
		messageHandlingQueue.addOperation(MessageHandlingOperation(messagesToHandle: messages, context: storage.newPrivateContext(), messageHandler: MobileMessaging.messageHandling, isNotificationTapped: notificationTapped, mmContext: mmContext, finishBlock: { error in
			
			self.messageSyncQueue.addOperation(MessageFetchingOperation(context: self.storage.newPrivateContext(),
			                                                            mmContext: self.mmContext,
			                                                            finishBlock: { completion?(MessageHandlingResult($0))})
			)
		}))
	}
	
	public func syncWithServer(_ completion: ((NSError?) -> Void)? = nil) {
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
	
	func updateOriginalPayloadsWithMessages(messages: [MessageId: MTMessage], completion: ((Void) -> Void)?) {
		guard !messages.isEmpty else
		{
			completion?()
			return
		}
		
		messageHandlingQueue.addOperation({
			let ctx = self.storage.newPrivateContext()
			ctx.performAndWait {
				let messageIds = messages.map { $0.key }
				MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIds), context: ctx)?.forEach { messageObj in
					guard let message = messages[messageObj.messageId] else {
						return
					}
					messageObj.payload = message.originalPayload
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
				MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageTypeValue == \(MMMessageType.Default.rawValue) AND messageId IN %@", sdkMessageIds), context: ctx)?.forEach { messageObj in
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
	
	var systemData: [String: AnyHashable]? {
		return nil
	}
	
	func populateNewPersistedMessage(_ message: inout MessageManagedObject, originalMessage: MTMessage) {
		guard !originalMessage.isGeoSignalingMessage else {
			return
		}
		
		// this code must perfrom only for non
		message.messageId = originalMessage.messageId
		message.creationDate = originalMessage.createdDate
		message.isSilent = originalMessage.isSilent
		message.reportSent = originalMessage.isDeliveryReportSent
		message.messageType = .Default
		message.payload = originalMessage.originalPayload
	}
	
	var isRunning: Bool = true
	
	var uniqueIdentifier: String {
		return "com.mobile-messaging.subservice.message-handler"
	}
	
	func start(_ completion: ((Bool) -> Void)? = nil) {
		isRunning = true
		if #available(iOS 10.0, *) {
			handleStorageFromNotificationServiceExtensionGroupContainer()
		}
		completion?(true)
	}
	
	func stop(_ completion: ((Bool) -> Void)? = nil) {
		isRunning = false
		completion?(true)
	}
	
	func mobileMessagingWillStart(_ mmContext: MobileMessaging) {
		
	}
	
	func mobileMessagingDidStart(_ mmContext: MobileMessaging) {
		
	}
	
	func mobileMessagingWillStop(_ mmContext: MobileMessaging) {
		
	}
	
	func mobileMessagingDidStop(_ mmContext: MobileMessaging) {
		stop()
	}
	
	func pushRegistrationStatusDidChange(_ mmContext: MobileMessaging) {
		if mmContext.isPushRegistrationEnabled == false {
			stop()
		} else {
			start()
		}
	}
	
	static func isNotificationTapped(_ message: MTMessage, applicationState: UIApplicationState) -> Bool {
		return applicationState == .inactive || message.isMessageLaunchingApplication == true
	}
}

extension MMMessageHandler {
	static func handleNotificationTap(with message: MTMessage) {
		MMQueue.Main.queue.executeAsync {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: MMNotificationMessageTapped), object: nil, userInfo: [MMNotificationKeyMessage: message])
			MobileMessaging.notificationTapHandler?(message)
		}
	}
}
