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
	public var queue: dispatch_queue_t {
		return serialQueue
	}
	
	override init() {
		self.delegateQueue = dispatch_get_main_queue()
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
	
	public func insert(outgoing messages: [MOMessage]) {
		guard let context = context where !messages.isEmpty else {
			return
		}
		var newMessages = [Message]()
		context.performBlockAndWait {
			messages.forEach { message in
				let newMessage = Message.MM_createEntityInContext(context: context)
				newMessage.payload = message.dictRepresentation
				newMessage.messageId = message.messageId
				newMessage.direction = MessageDirection.MO.rawValue
				newMessages.append(newMessage)
			}
			context.MM_saveToPersistentStoreAndWait()
		}
		self.callDelegateIfNeeded { self.delegate?.didInsertNewMessages(newMessages.baseMessages) }
	}
	
	public func insert(incoming messages: [MTMessage]) {
		guard let context = context where !messages.isEmpty else {
			return
		}
		var newMessages = [Message]()
		context.performBlockAndWait {
			messages.forEach { message in
				let newMessage = Message.MM_createEntityInContext(context: context)
				newMessage.payload = message.originalPayload
				newMessage.messageId = message.messageId
				newMessage.direction = MessageDirection.MT.rawValue
				newMessage.deliveryMethod = message.deliveryMethod.rawValue
				newMessages.append(newMessage)
			}
			context.MM_saveToPersistentStoreAndWait()
		}
		self.callDelegateIfNeeded { self.delegate?.didInsertNewMessages(newMessages.baseMessages) }
	}
	
	public func findMessage(withId messageId: MessageId) -> BaseMessage? {
		guard let context = self.context else {
			return nil
		}
		var result: BaseMessage?
		context.performBlockAndWait {
			if let message = Message.MM_findFirstInContext(NSPredicate(format: "messageId == %@", messageId), context: context), let baseMessage = message.baseMessage {
				result = baseMessage
			}
		}
		return result
	}
	
	public func update(messageSentStatus status: MOMessageSentStatus, for messageId: MessageId) {
		updateMessage(foundWith: NSPredicate(format: "messageId == %@", messageId)) { message in
			message.sentStatusValue = status.rawValue
		}
	}
	
	public func update(messageSeenStatus status: MMSeenStatus, for messageId: MessageId) {
		updateMessage(foundWith: NSPredicate(format: "messageId == %@", messageId)) { message in
			message.seenStatusValue = status.rawValue
		}
	}
	
	public func update(deliveryReportStatus isDelivered: Bool, for messageId: MessageId) {
		updateMessage(foundWith: NSPredicate(format: "messageId == %@", messageId)) { message in
			message.isDeliveryReportSent = isDelivered
		}
	}
	
	//MARK: - Convenience
	public weak var delegate: MessageStorageDelegate?
	public var delegateQueue: dispatch_queue_t
	
	//MARK: - MessageStorageFinders
	public func findAllMessages(completion: FetchResultBlock) {
		dispatch_async(queue) {
			guard let context = self.context else {
				completion(nil)
				return
			}
			context.performBlockAndWait {
				let messages = Message.MM_findAllWithPredicate(nil, inContext: context) as? [Message]
				completion(messages?.baseMessages)
			}
		}
	}
	
	public func findMessages(withIds messageIds: [MessageId], completion: FetchResultBlock) {
		dispatch_async(queue) {
			guard let context = self.context where !messageIds.isEmpty else {
				completion(nil)
				return
			}
			context.performBlockAndWait {
				let messages = Message.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIds), inContext: context) as? [Message]
				completion(messages?.baseMessages)
			}
		}
	}
	
	public func findMessages(withQuery query: Query, completion: FetchResultBlock) {
		dispatch_async(queue) {
			guard let context = self.context else {
				completion(nil)
				return
			}
			context.performBlockAndWait {
				let messages = Message.MM_findAll(withPredicate: query.predicate, sortDescriptors: query.sortDescriptors, limit: query.limit, skip: query.skip, inContext: context) as? [Message]
				completion(messages?.baseMessages)
			}
		}
	}
	
	//MARK: - MessageStorageRemovers
	public func removeAllMessages() {
		dispatch_async(queue) {
			guard let context = self.context else {
				return
			}
			context.performBlockAndWait {
				if let messages = Message.MM_findAllInContext(context) as? [Message] {
					self.delete(messages: messages)
				}
			}
		}
	}
	
	public func remove(withIds messageIds: [MessageId]) {
		dispatch_async(queue) {
			guard let context = self.context where !messageIds.isEmpty else {
				return
			}
			context.performBlockAndWait {
				if let messages = Message.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIds), inContext: context) as? [Message] {
					self.delete(messages: messages)
				}
			}
		}
	}
	
	public func remove(withQuery query: Query) {
		dispatch_async(queue) {
			guard let context = self.context else {
				return
			}
			context.performBlockAndWait {
				if let messages = Message.MM_findAll(withPredicate: query.predicate, sortDescriptors: query.sortDescriptors, limit: query.limit, skip: query.skip, inContext: context) as? [Message] {
					self.delete(messages: messages)
				}
			}
		}
	}
	
	// MARK: - Internal
	var coreDataStorage: MMCoreDataStorage?
	var context: NSManagedObjectContext?
	
	// MARK: - Private
	private let serialQueue: dispatch_queue_t = MMQueue.Serial.Reusable.MessageStorageQueue.queue.queue
	
	private func delete(messages messages: [Message]) {
		guard let context = context else {
			return
		}
		let deleted = messages.baseMessages
		messages.forEach { message in
			context.deleteObject(message)
		}
		context.MM_saveToPersistentStoreAndWait()
		self.callDelegateIfNeeded {
			self.delegate?.didRemoveMessages(deleted)
		}
	}
	
	private func didUpdate(message message: Message) {
		guard let baseMessage = message.baseMessage else {
			return
		}
		self.callDelegateIfNeeded {
			self.delegate?.didUpdateMessage(baseMessage)
		}
	}
	
	private func updateMessage(foundWith predicate: NSPredicate, applyChanges block: (Message) -> Void) {
		guard let context = context else {
			return
		}
		context.performBlockAndWait {
			if let message = Message.MM_findFirstInContext(predicate, context: context) {
				block(message)
				context.MM_saveToPersistentStore()
				self.didUpdate(message: message)
			}
		}
	}
	
	private func callDelegateIfNeeded(block: (Void -> Void)) {
		if self.delegate != nil {
			dispatch_async(delegateQueue, block)
		}
	}
}

extension Array where Element: Message {
	private var baseMessages: [BaseMessage] {
		return self.flatMap { $0.baseMessage }
	}
}