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

class MMMessageHandler: MobileMessagingService {
	lazy var messageHandlingQueue = MMOperationQueue.newSerialQueue
	lazy var messageSendingQueue = MMOperationQueue.userInitiatedQueue
	lazy var messageSyncQueue = MMOperationQueue.newSerialQueue
	lazy var seenPostponer = MMPostponer(executionQueue: DispatchQueue.main)
	
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

		if let msg = MTMessage(payload: userInfo) {
			handleMTMessages([msg], notificationTapped: MMMessageHandler.isNotificationTapped(msg, applicationState: mmContext.application.applicationState),completion: completion)
		} else {
			MMLogError("Error while converting payload:\n\(userInfo)\nto MMMessage")
			completion?(.failed(NSError.init(type: .UnknownError)))
		}
	}
	
	func handleMTMessage(_ message: MTMessage, notificationTapped: Bool = false, handlingIteration: Int = 0, completion: ((MessageHandlingResult) -> Void)? = nil) {
		handleMTMessages([message], notificationTapped: notificationTapped, handlingIteration: handlingIteration, completion: completion)
	}
	
	func handleMTMessages(_ messages: [MTMessage], notificationTapped: Bool = false, handlingIteration: Int = 0, completion: ((MessageHandlingResult) -> Void)? = nil) {
		guard isRunning == true, !messages.isEmpty else {
			completion?(.noData)
			return
		}
		
		messageHandlingQueue.addOperation(MessageHandlingOperation(messagesToHandle: messages, context: storage.newPrivateContext(), messageHandler: MobileMessaging.messageHandling, isNotificationTapped: notificationTapped, mmContext: mmContext, finishBlock:
			{ error, newMessages in
				let group =  DispatchGroup()
				
				for (_, subservice) in self.mmContext.subservices where subservice.uniqueIdentifier != self.uniqueIdentifier {
					newMessages?.forEach { m in
						group.enter()
						MMLogDebug("[Message Handler] subservice \(subservice.uniqueIdentifier) will start new message handling \(m.messageId)")
						subservice.handleNewMessage(m, completion: { result in
							MMLogDebug("[Message Handler] subservice \(subservice.uniqueIdentifier) did stop new message handling \(m.messageId)")
							group.leave()
						})
					}
					
					messages.forEach { m in
						group.enter()
						MMLogDebug("[Message Handler] subservice \(subservice.uniqueIdentifier) will start any message handling \(m.messageId)")
						subservice.handleAnyMessage(m, completion: { result in
							MMLogDebug("[Message Handler] subservice \(subservice.uniqueIdentifier) did stop any message handling \(m.messageId)")
							group.leave()
						})
					}
				}
		
				var result = MessageHandlingResult.noData
				group.enter()
				self.messageSyncQueue.addOperation(MessageFetchingOperation(context: self.storage.newPrivateContext(), mmContext: self.mmContext, handlingIteration: handlingIteration, finishBlock: { res in
					result = MessageHandlingResult(res)
					group.leave()
				}))
				
				group.notify(queue: DispatchQueue.global(qos: .default)) {
					MMLogDebug("[Message Handler] message handling finished")
					completion?(result)
				}
			}))
	}
	
	func syncMessagesWithOuterLocalSources(completion: @escaping () -> Void) {
		if !messageSyncQueue.addOperationExclusively(LocalMessageFetchingOperation(userNotificationCenterStorage: mmContext.userNotificationCenterStorage, notificationExtensionStorage: mmContext.sharedNotificationExtensionStorage, finishBlock: { messages in
			self.handleMTMessages(messages, notificationTapped: false, handlingIteration: 0, completion: { _ in
				completion()
			})
		})) {
			completion()
		}
	}
	
	public func syncWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		guard isRunning == true else {
			completion?(nil)
			return
		}
		syncMessagesWithOuterLocalSources() {
			self.syncMessagesWithServer(completion)
		}
	}
	
	func syncMessagesWithServer(_ completion: ((NSError?) -> Void)? = nil) {
		messageSyncQueue.addOperation(MessagesSyncOperation(context: storage.newPrivateContext(), mmContext: mmContext, finishBlock: completion))
	}
	
	func evictOldMessages(_ messageAge: TimeInterval? = nil, completion:(() -> Void)? = nil) {
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
	
	func updateOriginalPayloadsWithMessages(messages: [MessageId: MTMessage], completion: (() -> Void)?) {
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
	
	func updateDbMessagesCampaignFinishedState(forCampaignIds finishedCampaignIds: [String], completion: (() -> Void)?) {
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
	func updateSdkGeneratedTemporaryMessageIds(withMap messageIdsMap: [MessageId: MessageId], completion: (() -> Void)?) {
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
	
	func sendMessages(_ messages: [MOMessage], isUserInitiated: Bool, completion: (([MOMessage]?, NSError?) -> Void)? = nil) {
		messageSendingQueue.addOperation(MessagePostingOperation(messages: messages,
		                                                         isUserInitiated: isUserInitiated,
		                                                         context: storage.newPrivateContext(),
		                                                         mmContext: mmContext,
		                                                         finishBlock:
			{ (result: MOMessageSendingResult) in
				completion?(result.value?.messages, result.error)
			}
		))
	}
	
	func populateNewPersistedMessage(_ message: inout MessageManagedObject, originalMessage: MTMessage) -> Bool {
		guard !originalMessage.isGeoSignalingMessage else {
			MMLogDebug("[Message Handler] cannot populate message \(message.messageId)")
			return false
		}
		
		// this code must perfrom only for non
		message.creationDate = Date(timeIntervalSince1970: originalMessage.sendDateTime)
		message.messageId = originalMessage.messageId
		message.isSilent = originalMessage.isSilent
		message.reportSent = originalMessage.isDeliveryReportSent
		message.deliveryReportedDate = originalMessage.deliveryReportedDate
		message.messageType = .Default
		message.payload = originalMessage.originalPayload
		MMLogDebug("[Message Handler] attributes fulfilled for message \(message.messageId)")
		return true
	}
	
	var isRunning: Bool = true
	
	var uniqueIdentifier: String {
		return "com.mobile-messaging.subservice.MessageHandler"
	}
	
	func start(_ completion: ((Bool) -> Void)? = nil) {
		isRunning = true
		completion?(true)
	}
	
	func stop(_ completion: ((Bool) -> Void)? = nil) {
		isRunning = false
		messageHandlingQueue.cancelAllOperations()
		messageSendingQueue.cancelAllOperations()
		messageSyncQueue.cancelAllOperations()
		completion?(true)
	}
	
	func mobileMessagingWillStop(_ mmContext: MobileMessaging) {
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
