//
//  MMDefaultMessageStorage.swift
//
//  Created by Andrey K. on 15/09/16.
//
//

import Foundation
import CoreData

/// Default implementation of the Message Storage protocol. Uses Core Data persistent storage with SQLite database.
@objc public class MMDefaultMessageStorage: NSObject, MessageStorage, MessageStorageFinders, MessageStorageRemovers {
	public var queue: DispatchQueue {
		return serialQueue
	}
	
	override init() {
		self.delegateQueue = DispatchQueue.main
		super.init()
	}
	
	//MARK: - MessageStorage protocol
	public func start() {
		coreDataStorage = try? MMCoreDataStorage.makeSQLiteMessageStorage()
		context = coreDataStorage?.newPrivateContext()
	}
	
	public func stop() {
		context = nil
		coreDataStorage = nil
		delegate = nil
	}
	
	public func insert(outgoing messages: [MOMessage], completion: @escaping () -> Void) {
		persist(messages,
		        storageMessageConstructor: { (baseMessage, context) -> Message? in
					return Message.makeMoMessage(from: baseMessage, context: context)
				},
		        completion: completion)
	}
	
	public func insert(incoming messages: [MTMessage], completion: @escaping () -> Void) {
		persist(messages,
		        storageMessageConstructor: { (baseMessage, context) -> Message? in
					return Message.makeMtMessage(from: baseMessage, context: context)
				},
		        completion: completion)
	}
	
	public func findMessage(withId messageId: MessageId) -> BaseMessage? {
		guard let context = self.context else {
			return nil
		}
		var result: BaseMessage?
		context.performAndWait {
			if let message = Message.MM_findFirstWithPredicate(NSPredicate(format: "messageId == %@", messageId), context: context), let baseMessage = message.baseMessage {
				result = baseMessage
			}
		}
		return result
	}
	
	public func update(messageSentStatus status: MOMessageSentStatus, for messageId: MessageId, completion: @escaping () -> Void) {
		updateMessage(	foundWith: NSPredicate(format: "messageId == %@", messageId),
						applyChanges: { message in
							message.sentStatusValue = status.rawValue
						},
						completion: completion)
	}
	
	public func update(messageSeenStatus status: MMSeenStatus, for messageId: MessageId, completion: @escaping () -> Void) {
		updateMessage(	foundWith: NSPredicate(format: "messageId == %@", messageId),
						applyChanges: { message in
							message.seenStatusValue = status.rawValue
							if message.seenDate == nil && (status == .SeenNotSent || status == .SeenSent) {
								message.seenDate = MobileMessaging.date.now
							} else if status == .NotSeen {
								message.seenDate = nil
							}
						},
						completion: completion)
	}
	
	public func update(deliveryReportStatus isDelivered: Bool, for messageId: MessageId, completion: @escaping () -> Void) {
		updateMessage(	foundWith: NSPredicate(format: "messageId == %@", messageId),
		              	applyChanges: { message in
							message.isDeliveryReportSent = isDelivered
							message.deliveryReportedDate = isDelivered ? MobileMessaging.date.now : nil
						},
						completion: completion)
	}
	
	//MARK: - Convenience
	public weak var delegate: MessageStorageDelegate?
	public var delegateQueue: DispatchQueue
	
	//MARK: - MessageStorageFinders
	public func findAllMessages(completion: @escaping FetchResultBlock) {
		queue.async() {
			guard let context = self.context else {
				completion(nil)
				return
			}
			context.performAndWait {
				let messages = Message.MM_findAllWithPredicate(nil, context: context)
				completion(messages?.baseMessages)
			}
		}
	}
	
	public func findMessages(withIds messageIds: [MessageId], completion: @escaping FetchResultBlock) {
		queue.async() {
			guard let context = self.context , !messageIds.isEmpty else {
				completion(nil)
				return
			}
			context.performAndWait {
				let messages = Message.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIds), context: context)
				completion(messages?.baseMessages)
			}
		}
	}
	
	public func findMessages(withQuery query: Query, completion: @escaping FetchResultBlock) {
		queue.async() {
			guard let context = self.context else {
				completion(nil)
				return
			}
			context.performAndWait {
				let messages = Message.MM_findAll(withPredicate: query.predicate, sortDescriptors: query.sortDescriptors, limit: query.limit, skip: query.skip, inContext: context)
				completion(messages?.baseMessages)
			}
		}
	}
	
	//MARK: - MessageStorageRemovers
	public func removeAllMessages() {
		queue.async() {
			guard let context = self.context else {
				return
			}
			context.performAndWait {
				if let messages = Message.MM_findAllInContext(context) {
					self.delete(messages: messages)
				}
			}
		}
	}
	
	public func remove(withIds messageIds: [MessageId]) {
		queue.async() {
			guard let context = self.context , !messageIds.isEmpty else {
				return
			}
			context.performAndWait {
				if let messages = Message.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIds), context: context){
					self.delete(messages: messages)
				}
			}
		}
	}
	
	public func remove(withQuery query: Query) {
		queue.async() {
			guard let context = self.context else {
				return
			}
			context.performAndWait {
				if let messages = Message.MM_findAll(withPredicate: query.predicate, sortDescriptors: query.sortDescriptors, limit: query.limit, skip: query.skip, inContext: context) {
					self.delete(messages: messages)
				}
			}
		}
	}
	
	// MARK: - Internal
	var coreDataStorage: MMCoreDataStorage?
	var context: NSManagedObjectContext?
	
	// MARK: - Private
	private func persist(_ messages: [BaseMessage], storageMessageConstructor: @escaping (BaseMessage, NSManagedObjectContext) -> Message?, completion: () -> Void) {
		guard let context = self.context, !messages.isEmpty else {
			completion()
			return
		}
		
		var newMessages = [Message]()
		context.performAndWait {
			newMessages = messages.flatMap { storageMessageConstructor($0, context) }
			context.MM_saveToPersistentStoreAndWait()
		}
		completion()
		callDelegateIfNeeded {
			self.delegate?.didInsertNewMessages(newMessages.baseMessages)
		}
	}
	
	private let serialQueue: DispatchQueue = MMQueue.Serial.Reusable.MessageStorageQueue.queue.queue
	
	private func delete(messages: [Message]) {
		guard let context = context else {
			return
		}
		let deleted = messages.baseMessages
		messages.forEach { message in
			context.delete(message)
		}
		context.MM_saveToPersistentStoreAndWait()
		self.callDelegateIfNeeded {
			self.delegate?.didRemoveMessages(deleted)
		}
	}
	
	private func didUpdate(message: Message) {
		guard let baseMessage = message.baseMessage else {
			return
		}
		self.callDelegateIfNeeded {
			self.delegate?.didUpdateMessage(baseMessage)
		}
	}
	
	private func updateMessage(foundWith predicate: NSPredicate, applyChanges: @escaping (Message) -> Void, completion: @escaping () -> Void) {
		guard let context = context else {
			completion()
			return
		}
		context.performAndWait {
			guard let message = Message.MM_findFirstWithPredicate(predicate, context: context) else {
				completion()
				return
			}
			applyChanges(message)
			context.MM_saveToPersistentStoreAndWait()
			completion()
			self.didUpdate(message: message)
		}
	}
	
	private func callDelegateIfNeeded(block: @escaping (() -> Void)) {
		if self.delegate != nil {
			delegateQueue.async(execute: block)
		}
	}
}

extension MessageStorage {
	func batchDeliveryStatusUpdate(messages: [MessageManagedObject], completion: @escaping () -> Void) {
		let updatingGroup = DispatchGroup()
		messages.forEach {
			updatingGroup.enter()
			self.update(deliveryReportStatus: $0.reportSent, for: $0.messageId, completion: {
				updatingGroup.leave()
			})
		}
		updatingGroup.notify(queue: DispatchQueue.global(qos: .default), execute: completion)
	}
	
	func batchFailedSentStatusUpdate(messageIds: [String], completion: @escaping () -> Void) {
		let updatingGroup = DispatchGroup()
		messageIds.forEach {
			updatingGroup.enter()
			self.update(messageSentStatus: MOMessageSentStatus.SentWithFailure, for: $0, completion: {
				updatingGroup.leave()
			})
		}
		updatingGroup.notify(queue: DispatchQueue.global(qos: .default), execute: completion)
	}
	
	func batchSentStatusUpdate(messages: [MOMessage], completion: @escaping () -> Void) {
		let updatingGroup = DispatchGroup()
		messages.forEach {
			updatingGroup.enter()
			self.update(messageSentStatus: $0.sentStatus, for: $0.messageId, completion: {
				updatingGroup.leave()
			})
		}
		updatingGroup.notify(queue: DispatchQueue.global(qos: .default), execute: completion)
	}
	
	func batchSeenStatusUpdate(messages: [MessageManagedObject], completion: @escaping () -> Void) {
		let updatingGroup = DispatchGroup()
		messages.forEach {
			updatingGroup.enter()
			self.update(messageSeenStatus: $0.seenStatus, for: $0.messageId, completion: {
				updatingGroup.leave()
			})
		}
		updatingGroup.notify(queue: DispatchQueue.global(qos: .default), execute: completion)
	}
}

extension Array where Element: Message {
	fileprivate var baseMessages: [BaseMessage] {
		return self.flatMap { $0.baseMessage }
	}
}
