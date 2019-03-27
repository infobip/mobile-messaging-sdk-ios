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
	
	init(storage: MMCoreDataStorage, mmContext: MobileMessaging) {
		self.storage = storage
		super.init(mmContext: mmContext, id: "com.mobile-messaging.subservice.MessageHandler")
    }

	override func start(_ completion: @escaping (Bool) -> Void) {
		self.evictOldMessages(completion: { })
		super.start(completion)
	}

    //MARK: Intenal	
	func handleAPNSMessage(_ userInfo: APNSPayload, completion: ((MessageHandlingResult) -> Void)? = nil) {
		guard isRunning == true else {
			completion?(.noData)
			return
		}

		if let msg = MTMessage(payload: userInfo,
							   deliveryMethod: .push,
							   seenDate: nil,
							   deliveryReportDate: nil,
							   seenStatus: .NotSeen,
							   isDeliveryReportSent: false)
		{
			handleMTMessages([msg], notificationTapped: MMMessageHandler.isNotificationTapped(userInfo as? [String : Any], applicationState: MobileMessaging.application.applicationState), completion: completion)
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
		
		messageHandlingQueue.addOperation(MessageHandlingOperation(messagesToHandle: messages, context: storage.newPrivateContext(), isNotificationTapped: notificationTapped, mmContext: mmContext, finishBlock:
			{ error, newMessages in
				let group =  DispatchGroup()
				
				for (_, subservice) in self.mmContext.subservices where subservice.uniqueIdentifier != self.uniqueIdentifier {
					newMessages?.forEach { m in
						group.enter()
						MMLogDebug("[Message Handler] subservice \(subservice.uniqueIdentifier) will start new message handling \(m.messageId)")
						subservice.handleNewMessage(m, completion: { _ in
							MMLogDebug("[Message Handler] subservice \(subservice.uniqueIdentifier) did stop new message handling \(m.messageId)")
							group.leave()
						})
					}
					
					messages.forEach { m in
						group.enter()
						MMLogDebug("[Message Handler] subservice \(subservice.uniqueIdentifier) will start any message handling \(m.messageId)")
						subservice.handleAnyMessage(m, completion: { _ in
							MMLogDebug("[Message Handler] subservice \(subservice.uniqueIdentifier) did stop any message handling \(m.messageId)")
							group.leave()
						})
					}
				}
		
				var result = MessageHandlingResult.noData
				group.enter()
				self.syncMessages(handlingIteration: handlingIteration, finishBlock: { res in
					result = MessageHandlingResult(res)
					group.leave()
				})
				
				group.notify(queue: DispatchQueue.global(qos: .default)) {
					MMLogDebug("[Message Handler] message handling finished")
					completion?(result)
				}
			}))
	}

	func syncMessages(handlingIteration: Int, finishBlock: ((MessagesSyncResult) -> Void)? = nil) {
		self.messageSyncQueue.addOperation(MessageFetchingOperation(context: self.storage.newPrivateContext(), mmContext: self.mmContext, handlingIteration: handlingIteration, finishBlock: finishBlock))
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
	
	func syncMessagesWithServer(_ completion: @escaping (NSError?) -> Void) {
		messageSyncQueue.addOperation(MessagesSyncOperation(context: storage.newPrivateContext(), mmContext: mmContext, finishBlock: completion))
	}
	
	func evictOldMessages(_ messageAge: TimeInterval? = nil, completion: @escaping () -> Void) {
		messageHandlingQueue.addOperation(MessagesEvictionOperation(context: storage.newPrivateContext(), messageMaximumAge: messageAge, finishBlock: completion))
    }
    
	func setSeen(_ messageIds: [String], immediately: Bool, completion: @escaping () -> Void) {
        guard !messageIds.isEmpty else {
			completion()
            return
        }
		messageSyncQueue.addOperation(SeenStatusPersistingOperation(messageIds: messageIds, context: storage.newPrivateContext(), mmContext: mmContext, finishBlock: completion))
        if immediately {
			syncSeenStatusUpdates()
        } else {
            seenPostponer.postponeBlock() {
				self.syncSeenStatusUpdates()
            }
        }
    }
	
	func syncSeenStatusUpdates(_ completion: ((SeenStatusSendingResult) -> Void)? = nil) {
		messageSyncQueue.addOperation(SeenStatusSendingOperation(context: self.storage.newPrivateContext(), mmContext: mmContext, finishBlock: completion))
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
	
	func sendMessages(_ messages: [MOMessage], isUserInitiated: Bool, completion: @escaping ([MOMessage]?, NSError?) -> Void) {
		messageSendingQueue.addOperation(MessagePostingOperation(messages: messages,
		                                                         isUserInitiated: isUserInitiated,
		                                                         context: storage.newPrivateContext(),
		                                                         mmContext: mmContext,
		                                                         finishBlock:
			{ (result: MOMessageSendingResult) in
				completion(result.value?.messages, result.error)
			}
		))
	}

	override func syncWithServer(_ completion: @escaping (NSError?) -> Void) {
		guard isRunning == true else {
			completion(nil)
			return
		}
		syncMessagesWithOuterLocalSources() {
			self.syncMessagesWithServer(completion)
		}
	}

	override func populateNewPersistedMessage(_ message: inout MessageManagedObject, originalMessage: MTMessage) -> Bool {
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

	override func stop(_ completion: @escaping (Bool) -> Void) {
		cancelOperations()
		super.stop(completion)
	}

	override func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
		MMLogDebug("[Message handler] log out")
		cancelOperations()
		messageSyncQueue.addOperation {
			if let defaultMessageStorage = MobileMessaging.defaultMessageStorage {
				defaultMessageStorage.removeAllMessages() { _ in
					completion()
				}
			} else {
				completion()
			}
		}
	}
	
	override func mobileMessagingWillStop(_ mmContext: MobileMessaging) {
		stop({ _ in })
	}

	override func depersonalizationStatusDidChange(_ mmContext: MobileMessaging) {
		switch mmContext.internalData().currentDepersonalizationStatus {
		case .pending:
			stop({ _ in })
		case .success, .undefined:
			start({ _ in })
		}
	}

	override func pushRegistrationStatusDidChange(_ mmContext: MobileMessaging) {
		if mmContext.resolveInstallation().isPushRegistrationEnabled {
			start({ _ in })
		} else {
			stop({ _ in })
		}
	}
	
	static func isNotificationTapped(_ notificationUserInfo: [String: Any]?, applicationState: UIApplication.State) -> Bool {
		return applicationState == .inactive || (notificationUserInfo != nil ? notificationUserInfo![ApplicationLaunchedByNotification_Key] != nil : false)
	}

	private func cancelOperations() {
		messageHandlingQueue.cancelAllOperations()
		messageSendingQueue.cancelAllOperations()
		messageSyncQueue.cancelAllOperations()
	}
}
