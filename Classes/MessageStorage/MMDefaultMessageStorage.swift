//
//  MMDefaultMessageStorage.swift
//
//  Created by Andrey K. on 15/09/16.
//
//

import Foundation
import CoreData

/// Default implementation of the Message Storage protocol. Uses Core Data persistent storage with SQLite database.
@objc public class MMDefaultMessageStorage: NSObject, MMMessageStorage, MMMessageStorageFinders, MMMessageStorageRemovers {
	var totalMessagesCount_: Int = 0
	var nonSeenMessagesCount_: Int = 0
	
	func updateCounters(total: Int?, nonSeen: Int?, force: Bool? = false) {
		var doCall: Bool = false
		if let total = total, total != totalMessagesCount_ {
			doCall = true
			totalMessagesCount_ = total
		}
		if let nonSeen = nonSeen, nonSeen != nonSeenMessagesCount_ {
			doCall = true
			nonSeenMessagesCount_ = nonSeen
		}
		if doCall || (force ?? false) {
			OperationQueue.main.addOperation {
				self.messagesCountersUpdateHandler?(self.totalMessagesCount_, self.nonSeenMessagesCount_)
			}
		}
	}
	
	public var messagesCountersUpdateHandler: ((Int, Int) -> Void)? = nil {
		didSet {
			updateCounters(total: totalMessagesCount_, nonSeen: nonSeenMessagesCount_, force: true)
		}
	}
	
	static func makeDefaultMessageStorage() -> MMDefaultMessageStorage? {
		if let s = try? MMCoreDataStorage.makeSQLiteMessageStorage() {
			return MMDefaultMessageStorage(coreDataStorage: s)
		} else {
			MMLogError("Mobile messaging failed to initialize default message storage")
			return nil
		}
	}
	
	public func countAllMessages(completion: @escaping (Int) -> Void) {
		guard let context = self.context else {
			completion(0)
			return
		}
		
		context.perform {
			completion(Message.MM_countOfEntitiesWithContext(context))
		}
	}
	
	public var queue: DispatchQueue {
		return serialQueue
	}
	
	init(coreDataStorage: MMCoreDataStorage) {
		self.coreDataStorage = coreDataStorage
		self.delegateQueue = DispatchQueue.main
		super.init()
	}
	
	//MARK: - MessageStorage protocol
	public func start() {
		context = coreDataStorage?.newPrivateContext()
		initMessagesCounters()
	}
	
	public func stop() {
		context = nil
		coreDataStorage = nil
		delegate = nil
	}
	
	public func findAllMessageIds(completion: @escaping (([String]) -> Void)) {
		guard let context = self.context else {
			completion([])
			return
		}
		context.perform {
			let messageIds = Message.MM_selectAttribute("messageId", withPredicte: nil, inContext: context)
			self.updateCounters(total: messageIds?.count ?? 0, nonSeen: nil)
			completion(messageIds as? [String] ?? [])
		}
	}

	public func findNonSeenMessageIds(completion: @escaping (([String]) -> Void)) {
		guard let context = self.context else {
			completion([])
			return
		}
		context.perform {
			let predicate = NSPredicate(format: "seenStatusValue == \(MMSeenStatus.NotSeen.rawValue)")
			let messageIds = Message.MM_selectAttribute("messageId", withPredicte: predicate, inContext: context)
			self.updateCounters(total: nil, nonSeen: messageIds?.count ?? 0)
			completion(messageIds as? [String] ?? [])
		}
	}

	public func insert(outgoing messages: [MMBaseMessage], completion: @escaping () -> Void) {
		persist(
			messages,
			storageMessageConstructor: { (baseMessage, context) -> Message? in
				return Message.makeMoMessage(from: baseMessage, context: context)
			},
			completion: completion)
	}
	
	public func insert(incoming messages: [MMBaseMessage], completion: @escaping () -> Void) {
		persist(
			messages,
			storageMessageConstructor: { (baseMessage, context) -> Message? in
				return Message.makeMtMessage(from: baseMessage, context: context)
			},
			completion: {
				self.updateCounters(total: totalMessagesCount_ + messages.count, nonSeen: self.nonSeenMessagesCount_ + messages.count)
				completion()
			})
	}
	
	public func findMessage(withId messageId: MessageId) -> MMBaseMessage? {
		guard let context = self.context else {
			return nil
		}
		var result: MMBaseMessage?
		context.performAndWait {
			if let message = Message.MM_findFirstWithPredicate(NSPredicate(format: "messageId == %@", messageId), context: context), let baseMessage = message.baseMessage {
				result = baseMessage
			}
		}
		return result
	}
	
	public func update(messageSentStatus status: MM_MOMessageSentStatus, for messageId: MessageId, completion: @escaping () -> Void) {
		updateMessages(
			foundWith: NSPredicate(format: "messageId == %@", messageId),
			applyChanges: { message in message.sentStatusValue = status.rawValue },
			completion: completion)
	}
	
	public func update(messageSeenStatus status: MMSeenStatus, for messageId: MessageId, completion: @escaping () -> Void) {
		var newSeenMessagsCount = 0
		updateMessages(
			foundWith: NSPredicate(format: "messageId == %@", messageId),
			applyChanges: { message in
				message.seenStatusValue = status.rawValue
				if message.seenDate == nil && (status == .SeenNotSent || status == .SeenSent) {
					message.seenDate = MobileMessaging.date.now
					newSeenMessagsCount += 1
				} else if status == .NotSeen {
					message.seenDate = nil
				}
			},
			completion: {
				self.updateCounters(total: nil, nonSeen: max(0, self.nonSeenMessagesCount_ - newSeenMessagsCount))
				completion()
			})
	}
	
	public func update(deliveryReportStatus isDelivered: Bool, for messageId: MessageId, completion: @escaping () -> Void) {
		updateMessages(
			foundWith: NSPredicate(format: "messageId == %@", messageId),
			applyChanges: { message in
				message.isDeliveryReportSent = isDelivered
				message.deliveryReportedDate = isDelivered ? MobileMessaging.date.now : nil
			},
			completion: completion)
	}
	
	//MARK: - Convenience
	public weak var delegate: MMMessageStorageDelegate?
	public var delegateQueue: DispatchQueue
	
	//MARK: - MessageStorageFinders
	public func findAllMessages(completion: @escaping FetchResultBlock) {
		queue.async() {
			guard let context = self.context else {
				completion(nil)
				return
			}
			var baseMessages: [MMBaseMessage]? = nil
			context.performAndWait {
				let messages = Message.MM_findAllWithPredicate(nil, context: context)
				self.updateCounters(total: messages?.count ?? 0, nonSeen: nil)
				baseMessages = messages?.baseMessages
			}
			completion(baseMessages)
		}
	}
	
	public func findMessages(withIds messageIds: [MessageId], completion: @escaping FetchResultBlock) {
		queue.async() {
			guard let context = self.context , !messageIds.isEmpty else {
				completion(nil)
				return
			}
			var messages: [Message]? = nil
			context.performAndWait {
				messages = Message.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIds), context: context)
			}
			completion(messages?.baseMessages)
		}
	}
	
	public func findMessages(withQuery query: MMQuery, completion: @escaping FetchResultBlock) {
		queue.async() {
			guard let context = self.context else {
				completion(nil)
				return
			}
			var messages: [Message]? = nil
			context.performAndWait {
				messages = Message.MM_findAll(withPredicate: query.predicate, sortDescriptors: query.sortDescriptors, limit: query.limit, skip: query.skip, inContext: context)
			}
			completion(messages?.baseMessages)
		}
	}
	
	//MARK: - MessageStorageRemovers
	public func removeAllMessages(completion: @escaping ([MessageId]) -> Void) {
		queue.async() {
			guard let context = self.context else {
				completion([])
				return
			}
			var removedMsgIds: [MessageId] = []
			context.performAndWait {
				if let messages = Message.MM_findAllInContext(context) {
					removedMsgIds.append(contentsOf: messages.map({ $0.messageId }))
					self.delete(messages: messages)
					self.updateCounters(total: 0, nonSeen: 0)
				}
			}
			completion(removedMsgIds)
		}
	}
	
	public func remove(withIds messageIds: [MessageId], completion: @escaping ([MessageId]) -> Void) {
		queue.async() {
			guard let context = self.context , !messageIds.isEmpty else {
				completion([])
				return
			}
			var removedMsgIds: [MessageId] = []
			context.performAndWait {
				if let messages = Message.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIds), context: context)
				{
					let deletedNonSeenCount = messages.filter({ $0.seenStatusValue == MMSeenStatus.NotSeen.rawValue }).count
					let deletedCount = messages.count
					removedMsgIds.append(contentsOf: messages.map({ $0.messageId }))
					self.delete(messages: messages)
					self.updateCounters(total: max(0, self.totalMessagesCount_ - deletedCount), nonSeen: max(0, self.nonSeenMessagesCount_ - deletedNonSeenCount))
				}
			}
			completion(removedMsgIds)
		}
	}
	
	public func remove(withQuery query: MMQuery, completion: @escaping ([MessageId]) -> Void) {
		queue.async() {
			guard let context = self.context else {
				completion([])
				return
			}
			var removedMsgIds: [MessageId] = []
			context.performAndWait {
				if let messages = Message.MM_findAll(withPredicate: query.predicate, sortDescriptors: query.sortDescriptors, limit: query.limit, skip: query.skip, inContext: context)
				{
					let deletedNonSeenCount = messages.filter({ $0.seenStatusValue == MMSeenStatus.NotSeen.rawValue }).count
					let deletedCount = messages.count
					removedMsgIds.append(contentsOf: messages.map({ $0.messageId }))
					self.delete(messages: messages)
					self.updateCounters(total: max(0, self.totalMessagesCount_ - deletedCount), nonSeen: max(0, self.nonSeenMessagesCount_ - deletedNonSeenCount))
				}
			}
			completion(removedMsgIds)
		}
	}
	
	// MARK: - Internal
	var coreDataStorage: MMCoreDataStorage?
	var context: NSManagedObjectContext?
	
	// MARK: - Private
	private func initMessagesCounters() {
		self.countAllAndNonSeenMessages(completion: { total, nonSeen in
			self.updateCounters(total: total, nonSeen: nonSeen)
		})
	}
	
	private func countAllAndNonSeenMessages(completion: @escaping (Int, Int) -> Void) {
		guard let context = self.context else {
			completion(0, 0)
			return
		}
		
		context.perform {
			let predicate = NSPredicate(format: "seenStatusValue == \(MMSeenStatus.NotSeen.rawValue)")
			completion(Message.MM_countOfEntitiesWithContext(context), Message.MM_countOfEntitiesWithPredicate(predicate, inContext: context))
		}
	}
	
	private func persist(_ messages: [MMBaseMessage], storageMessageConstructor: @escaping (MMBaseMessage, NSManagedObjectContext) -> Message?, completion: () -> Void) {
		guard let context = self.context, !messages.isEmpty else {
			completion()
			return
		}

		let persistedMessageIds: Set<String> = Set(Message.MM_selectAttribute("messageId", withPredicte: nil, inContext: context) as? Array<String> ?? Array())

		let messagesToStore = messages.filter({ !persistedMessageIds.contains($0.messageId) })
		if !messagesToStore.isEmpty {
			context.performAndWait {
				messagesToStore.forEach({
					_ = storageMessageConstructor($0, context)
				})
				context.MM_saveToPersistentStoreAndWait()
			}
		}

		completion()
		callDelegateIfNeeded {
			self.delegate?.didInsertNewMessages(messagesToStore)
		}
	}
	
	private let serialQueue: DispatchQueue = MMQueue.Serial.New.MessageStorageQueue.queue.queue
	
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
	
	private func updateMessages(foundWith predicate: NSPredicate, applyChanges: @escaping (Message) -> Void, completion: @escaping () -> Void) {
		guard let context = context else {
			completion()
			return
		}
		context.performAndWait {
			Message.MM_findAllWithPredicate(predicate, context: context)?.forEach {
				applyChanges($0)
				context.MM_saveToPersistentStoreAndWait()
				self.didUpdate(message: $0)
			}
		}
		completion()
	}
	
	private func callDelegateIfNeeded(block: @escaping (() -> Void)) {
		if self.delegate != nil {
			delegateQueue.async(execute: block)
		}
	}
}

extension MMMessageStorage {
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
			self.update(messageSentStatus: MM_MOMessageSentStatus.SentWithFailure, for: $0, completion: {
				updatingGroup.leave()
			})
		}
		updatingGroup.notify(queue: DispatchQueue.global(qos: .default), execute: completion)
	}
	
	func batchSentStatusUpdate(messages: [MM_MOMessage], completion: @escaping () -> Void) {
		let updatingGroup = DispatchGroup()
		messages.forEach {
			updatingGroup.enter()
			self.update(messageSentStatus: $0.sentStatus, for: $0.messageId, completion: {
				updatingGroup.leave()
			})
		}
		updatingGroup.notify(queue: DispatchQueue.global(qos: .default), execute: completion)
	}
	
	func batchSeenStatusUpdate(messageIds: [String], seenStatus: MMSeenStatus, completion: @escaping () -> Void) {
		let updatingGroup = DispatchGroup()
		messageIds.forEach {
			updatingGroup.enter()
			self.update(messageSeenStatus: seenStatus, for: $0, completion: {
				updatingGroup.leave()
			})
		}
		updatingGroup.notify(queue: DispatchQueue.global(qos: .default), execute: completion)
	}
}

extension Array where Element: Message {
	fileprivate var baseMessages: [MMBaseMessage] {
		return self.compactMap { $0.baseMessage }
	}
}
