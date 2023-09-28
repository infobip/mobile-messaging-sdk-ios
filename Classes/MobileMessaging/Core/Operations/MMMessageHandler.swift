//
//  MMMessageHandler.swift
//  MobileMessaging
//
//  Created by Andrey K. on 24/02/16.
//  
//

import Foundation
import CoreData

public enum MessageHandlingResult {
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

public class MMMessageHandler: MobileMessagingService {
    private let q: DispatchQueue
    let messageHandlingQueue: MMOperationQueue
    let messageSendingQueue: MMOperationQueue
    let messageSyncQueue: MMOperationQueue
	lazy var seenPostponer = MMPostponer(executionQueue: DispatchQueue.main)
	let storage: MMCoreDataStorage
	
	init(storage: MMCoreDataStorage, mmContext: MobileMessaging) {
		self.storage = storage
        self.q = DispatchQueue(label: "message-handler", qos: DispatchQoS.default, attributes: .concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
        self.messageHandlingQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q)
        self.messageSendingQueue = MMOperationQueue.userInitiatedQueue(underlyingQueue: q)
        self.messageSyncQueue = MMOperationQueue.newSerialQueue(underlyingQueue: q)
		super.init(mmContext: mmContext, uniqueIdentifier: "MMMessageHandler")
    }

    public override func start(_ completion: @escaping (Bool) -> Void) {
        super.start({ _ in })
        evictOldMessages(userInitiated: false, completion: {
            self.syncWithServer(userInitiated: false) {_ in  completion(self.isRunning)}
        })
	}

    // MARK: - Internal
    func handleAPNSMessage(userInitiated: Bool, userInfo: MMAPNSPayload, completion: @escaping (MessageHandlingResult) -> Void) {
		guard isRunning == true else {
            logDebug("abort messages handling, service running \(isRunning)")
			completion(.noData)
			return
		}
        
        if let msg = MM_MTMessage(payload: userInfo,
                         deliveryMethod: .push,
                         seenDate: nil,
                         deliveryReportDate: nil,
                         seenStatus: .NotSeen,
                         isDeliveryReportSent: false)
        {
            handleMTMessages(userInitiated: userInitiated, messages: [msg], notificationTapped: MMMessageHandler.isNotificationTapped(userInfo as? [String : Any], applicationState: MobileMessaging.application.applicationState), completion: completion)
		} else {
			logError("Error while converting payload:\n\(userInfo)\nto MMMessage")
			completion(.failed(NSError.init(type: .UnknownError)))
		}
	}
	
    func handleMTMessage(userInitiated: Bool, message: MM_MTMessage, notificationTapped: Bool = false, handlingIteration: Int = 0, completion: @escaping (MessageHandlingResult) -> Void) {
        handleMTMessages(userInitiated: userInitiated, messages: [message], notificationTapped: notificationTapped, handlingIteration: handlingIteration, completion: completion)
	}
	
    public func handleMTMessages(userInitiated: Bool, messages: [MM_MTMessage], notificationTapped: Bool = false, handlingIteration: Int = 0, completion: @escaping (MessageHandlingResult) -> Void) {
		guard isRunning == true, !messages.isEmpty else {
            logDebug("abort messages handling \(messages), service running \(isRunning)")
			completion(.noData)
			return
		}
		 
        let messagesToHandle = messages.map { message in
            return MMInAppMessage(payload: message.originalPayload,
                                  deliveryMethod: .push,
                                  seenDate: nil,
                                  deliveryReportDate: nil,
                                  seenStatus: .NotSeen,
                                  isDeliveryReportSent: false)
          ?? message
        }
        messageHandlingQueue.addOperation(MessageHandlingOperation(userInitiated: userInitiated, messagesToHandle: messagesToHandle, context: storage.newPrivateContext(), isNotificationTapped: notificationTapped, mmContext: mmContext, finishBlock:
			{ [weak self] error, newMessages in
            
                guard let _self = self else {
                    completion(.noData)
                    return
                }
				let group =  DispatchGroup()
				
				for (_, subservice) in _self.mmContext.subservices where subservice.uniqueIdentifier != _self.uniqueIdentifier {
					newMessages?.forEach { m in
						group.enter()
                        _self.logDebug("subservice \(subservice.uniqueIdentifier) will start new message handling \(m.messageId)")
						subservice.handleNewMessage(m, completion: { _ in
                            _self.logDebug("subservice \(subservice.uniqueIdentifier) did stop new message handling \(m.messageId)")
							group.leave()
						})
					}
					
					messages.forEach { m in
						group.enter()
                        _self.logDebug("subservice \(subservice.uniqueIdentifier) will start any message handling \(m.messageId)")
						subservice.handleAnyMessage(m, completion: { _ in
                            _self.logDebug("subservice \(subservice.uniqueIdentifier) did stop any message handling \(m.messageId)")
							group.leave()
						})
					}
				}
		
				var result = MessageHandlingResult.noData
				group.enter()
                _self.syncMessages(userInitiated: userInitiated, handlingIteration: handlingIteration, finishBlock: { res in
					result = MessageHandlingResult(res)
					group.leave()
				})
				
                let q = userInitiated ? DispatchQueue.main : DispatchQueue.global(qos: .default)
				group.notify(queue: q) {
                    _self.logDebug("message handling finished")
					completion(result)
				}
			}))
	}

    func syncMessages(userInitiated: Bool, handlingIteration: Int, finishBlock: @escaping (MessagesSyncResult) -> Void) {
        guard isRunning else {
            logDebug("abort message fethcing, service running \(isRunning)")
            finishBlock(MessagesSyncResult.Cancel)
            return
        }
        self.messageSyncQueue.addOperation(MessageFetchingOperation(userInitiated: userInitiated, context: self.storage.newPrivateContext(), mmContext: self.mmContext, handlingIteration: handlingIteration, finishBlock: finishBlock))
	}
	
    func syncMessagesWithOuterLocalSources(userInitiated: Bool, completion: @escaping () -> Void) {
        guard isRunning else {
            logDebug("abort syncing with outer local storage, service running \(isRunning)")
            completion()
            return
        }
		if !messageSyncQueue.addOperationExclusively(LocalMessageFetchingOperation(userNotificationCenterStorage: mmContext.userNotificationCenterStorage, notificationExtensionStorage: mmContext.sharedNotificationExtensionStorage, finishBlock: { messages in
            self.handleMTMessages(userInitiated: userInitiated, messages: messages, notificationTapped: false, handlingIteration: 0, completion: { _ in
				completion()
			})
		})) {
			completion()
		}
	}
	
    func syncMessagesWithServer(userInitiated: Bool, completion: @escaping (NSError?) -> Void) {
        guard isRunning else {
            logDebug("abort syncing with server, service running \(isRunning)")
            completion(nil)
            return
        }
        messageSyncQueue.addOperation(MessagesSyncOperation(userInitiated: userInitiated, context: storage.newPrivateContext(), mmContext: mmContext, finishBlock: completion))
	}
	
    func evictOldMessages(userInitiated: Bool, messageAge: TimeInterval? = nil, completion: @escaping () -> Void) {
        guard isRunning else {
            logDebug("abort evicting, service running \(isRunning)")
            completion()
            return
        }
        messageHandlingQueue.addOperation(MessagesEvictionOperation(userInitiated: userInitiated, context: storage.newPrivateContext(), messageMaximumAge: messageAge, finishBlock: completion))
    }
    
	func setSeen(userInitiated: Bool, messageIds: [String], immediately: Bool, completion: @escaping () -> Void) {
        guard isRunning else {
            logDebug("abort setting seen, service running \(isRunning)")
            completion()
            return
        }
        guard !messageIds.isEmpty else {
			completion()
            return
        }
        messageSyncQueue.addOperation(SeenStatusPersistingOperation(userInitiated: userInitiated, messageIds: messageIds, context: storage.newPrivateContext(), mmContext: mmContext, finishBlock: completion))
        if immediately {
			syncSeenStatusUpdates(userInitiated: false)
        } else {
            seenPostponer.postponeBlock() {
				self.syncSeenStatusUpdates(userInitiated: false)
            }
        }
    }
	
	public func syncSeenStatusUpdates(userInitiated: Bool, completion: ((SeenStatusSendingResult) -> Void)? = nil) {
        guard isRunning else {
            logDebug("abort syncing seen statuses, service running \(isRunning)")
            completion?(SeenStatusSendingResult.Cancel)
            return
        }
        messageSyncQueue.addOperation(SeenStatusSendingOperation(userInitiated: userInitiated, context: self.storage.newPrivateContext(), mmContext: mmContext, finishBlock: completion))
	}
	
	public func updateOriginalPayloadsWithMessages(messages: [MessageId: MM_MTMessage], completion: (() -> Void)?) {
        guard isRunning else {
            logDebug("abort updating original paylaod, service running \(isRunning)")
            completion?()
            return
        }
		guard !messages.isEmpty else {
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
	
	public func updateDbMessagesCampaignFinishedState(forCampaignIds finishedCampaignIds: [String], completion: (() -> Void)?) {
        guard isRunning else {
            logDebug("abort updating campaigns finished status, service running \(isRunning)")
            completion?()
            return
        }
		guard !finishedCampaignIds.isEmpty else {
			completion?()
			return
		}
		
		messageHandlingQueue.addOperation({
			let ctx = self.storage.newPrivateContext()
			ctx.performAndWait {
				MessageManagedObject.MM_batchUpdate(propertiesToUpdate: ["campaignStateValue": MMCampaignState.Finished.rawValue], predicate: NSPredicate(format: "campaignId IN %@", finishedCampaignIds), inContext: ctx)
			}
			ctx.MM_saveToPersistentStoreAndWait()
			completion?()
		})
	}
	
	/// - parameter messageIdsMap: contains pairs of message ids generated by the sdk as a key and real message ids generated by IPCore as a vlue
	public func updateSdkGeneratedTemporaryMessageIds(withMap messageIdsMap: [MessageId: MessageId], completion: (() -> Void)?) {
        guard isRunning else {
            logDebug("abort updating temporal msg ids, service running \(isRunning)")
            completion?()
            return
        }
		//if the sdk generated message id was mapped with real message id, we should update all stored messages
		let sdkMessageIds = Array(messageIdsMap.keys)
		guard !sdkMessageIds.isEmpty else {
			completion?()
			return
		}
		
		messageHandlingQueue.addOperation({
			let ctx = self.storage.newPrivateContext()
			ctx.performAndWait {
				MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageTypeValue == \(MMMessageType.Default.rawValue) AND messageId IN %@", sdkMessageIds), context: ctx)?.forEach { messageObj in
					if let realMessageId = messageIdsMap[messageObj.messageId] {
						messageObj.messageId = realMessageId
					}
				}
			}
			ctx.MM_saveToPersistentStoreAndWait()
			completion?()
		})
	}
	
    func sendMessages(messages: [MM_MOMessage], isUserInitiated: Bool, completion: @escaping ([MM_MOMessage]?, NSError?) -> Void) {
        guard isRunning else {
            logDebug("abort sending messages, service running \(isRunning)")
            completion(nil, nil)
            return
        }
        messageSendingQueue.addOperation(MessagePostingOperation(userInitiated: isUserInitiated,
                                                                 messages: messages,
		                                                         isUserInitiated: isUserInitiated,
		                                                         context: storage.newPrivateContext(),
		                                                         mmContext: mmContext,
		                                                         finishBlock:
			{ (result: MOMessageSendingResult) in
				completion(result.value?.messages, result.error)
			}
		))
	}

    public override func appWillEnterForeground(_ completion: @escaping () -> Void) {
		syncWithServer(userInitiated: false) {_ in completion() }
	}

    func syncWithServer(userInitiated: Bool, completion: @escaping (NSError?) -> Void) {
        assert(!Thread.isMainThread)
        syncMessagesWithOuterLocalSources(userInitiated: userInitiated) {
            self.syncMessagesWithServer(userInitiated: userInitiated, completion: completion)
		}
	}

    public override func populateNewPersistedMessage(_ message: inout MessageManagedObject, originalMessage: MM_MTMessage) -> Bool {
		guard !originalMessage.isGeoSignalingMessage else {
			logDebug("cannot populate message \(message.messageId)")
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
		logDebug("attributes fulfilled for message \(message.messageId)")
		return true
	}

    public override func suspend() {
        logDebug("suspending...")
        cancelOperations()
        super.suspend()
	}

    public override func depersonalizeService(_ mmContext: MobileMessaging, completion: @escaping () -> Void) {
		logDebug("depersonalizing...")
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
	
    public override func depersonalizationStatusDidChange(_ completion: @escaping () -> Void) {
		switch mmContext.internalData().currentDepersonalizationStatus {
		case .pending:
            suspend()
            completion()
		case .success, .undefined:
			start({ _ in completion() })
		}
	}

    public override func pushRegistrationStatusDidChange(_ completion: @escaping () -> Void) {
		if mmContext.resolveInstallation().isPushRegistrationEnabled {
			start({ _ in completion() })
		} else {
            suspend()
            completion()
		}
	}
    
    override func baseUrlDidChange(_ completion: @escaping () -> Void) {
        syncWithServer(userInitiated: false) {_ in completion() }
    }
	
	static func isNotificationTapped(_ notificationUserInfo: [String: Any]?, applicationState: UIApplication.State) -> Bool {
        //plugins aren't supported with swift package
        //FIXME: ApplicationLaunchedByNotification_Key was used in plugins only, might be removed, looks not used at all
        #if SWIFT_PACKAGE
        return applicationState == .inactive
        #else
        return applicationState == .inactive || (notificationUserInfo != nil ? notificationUserInfo![ApplicationLaunchedByNotification_Key] != nil : false)
        #endif
	}

	private func cancelOperations() {
        logDebug("Canceling all messageHandlingQueue, messageSendingQueue, messageSyncQueue operations")
		messageHandlingQueue.cancelAllOperations()
		messageSendingQueue.cancelAllOperations()
		messageSyncQueue.cancelAllOperations()
	}
}
