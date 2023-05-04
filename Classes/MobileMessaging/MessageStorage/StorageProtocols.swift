//
//  StorageProtocols.swift
//
//  Created by Andrey K. on 15/09/16.
//

import Foundation

public typealias MessageId = String
public typealias FetchResultBlock = ([MMBaseMessage]?) -> Void

/// The class defines a query that is used to fetch messages from the Message Storage.
@objcMembers
public class MMQuery: NSObject {
	/// A limit on the number of objects to return. The default limit is undefined (unlimited).
	public var limit: Int?
	
	/// The number of objects to skip before returning any. The default value is 0.
	public var skip: Int?

	/// - Note:
	/// The following types of predicates are supported:
	///
	/// - Simple comparisons such as `=`, `!=`, `<`, `>`, `<=`, `>=`, and `BETWEEN` with a key and a constant.
	/// - Containment predicates, such as `x IN {1, 2, 3}`.
	/// - Key-existence predicates, such as `x IN SELF`.
	/// - `BEGINSWITH` expressions.
	/// - Compound predicates with `AND`, `OR`, and `NOT`.
	/// - SubQueries with key IN %@, subquery.
	///
	/// The following types of predicates are NOT supported:
	///
	/// - Aggregate operations, such as `ANY`, `SOME`, `ALL`, or `NONE`.
	/// - Regular expressions, such as `LIKE`, `MATCHES`, `CONTAINS`, or `ENDSWITH`.
	/// - Predicates comparing one key to another.
	/// - Complex predicates with many ORed clauses.
	public var predicate: NSPredicate?
	
	/// An array of `NSSortDescriptor` objects to use to sort the results of the query.
	public var sortDescriptors: [NSSortDescriptor]?
	
	override public init() {
		super.init()
	}
}

@objc public protocol MMMessageStorageDelegate {
	func didInsertNewMessages(_ messages: [MMBaseMessage])
	func didUpdateMessage(_ message: MMBaseMessage)
	func didRemoveMessages(_ messages: [MMBaseMessage])
}

@objc public protocol MMMessageStorageFinders {
	var messagesCountersUpdateHandler: ((Int, Int) -> Void)? {get set}
	func countAllMessages(completion: @escaping (Int) -> Void)
	func findAllMessages(completion: @escaping FetchResultBlock)
	func findAllMessageIds(completion: @escaping (([String]) -> Void))
	func findNonSeenMessageIds(completion: @escaping (([String]) -> Void))
	func findMessages(withIds messageIds: [MessageId], completion: @escaping FetchResultBlock)
	func findMessages(withQuery query: MMQuery, completion: @escaping FetchResultBlock)
}

@objc public protocol MMMessageStorageRemovers {
	func removeAllMessages(completion: @escaping ([MessageId]) -> Void)
	func remove(withIds messageIds: [MessageId], completion: @escaping ([MessageId]) -> Void)
	func remove(withQuery query: MMQuery, completion: @escaping ([MessageId]) -> Void)
}

/// The protocol describes implementation of the Message Storage. The Message Storage persists all the messages (both mobile originated and mobile terminated).
@objc public protocol MMMessageStorage {
	/// The queue in which all the hooks(inserts, updates) are dispatched.
	/// The queue must be provided by the particular implementation of this protocol in order to provide thread safety and performance aspects.
	var queue: DispatchQueue {get}
	
	/// This method is called by the Mobile Messaging SDK during the initialization process. You implement your custom preparation routine here if needed.
	func start()
	
	/// This method is called by the Mobile Messaging SDK while stopping the currently running session (see also `MobileMessaging.stop()` method). You implement your custom deinitialization routine here if needed.
	func stop()
	
	/// This method is called whenever a new mobile originated message is about to be sent to the server.
	func insert(outgoing messages: [MMBaseMessage], completion: @escaping () -> Void)
	
	/// This method is called whenever a new mobile terminated message (either push(remote) notifictaion or fetched message) is received by the Mobile Messaging SDK.
	func insert(incoming messages: [MMBaseMessage], completion: @escaping () -> Void)
	
	/// This method is used by the Mobile Messaging SDK in order to detect duplicated messages persisted in the Message Storage. It is strongly recommended to implement this method in your custom Message Storage.
	/// - parameter messageId: unique identifier of a MT message. Consider this identifier as a primary key.
	func findMessage(withId messageId: MessageId) -> MMBaseMessage?
	
	/// This method is called whenever the seen status is updated for a particular mobile terminated (MT) message.
	/// - parameter status: actual seen status for a message
	/// - parameter messageId: unique identifier of a MT message
	func update(messageSeenStatus status: MMSeenStatus, for messageId: MessageId, completion: @escaping () -> Void)
	
	/// This method is called whenever the delivery report is updated for a particular mobile terminated (MT) message.
	/// - parameter isDelivered: boolean flag which defines whether the delivery report for a message was successfully sent
	/// - parameter messageId: unique identifier of a MT message
	func update(deliveryReportStatus isDelivered: Bool, for messageId: MessageId, completion: @escaping () -> Void)
	
	/// This method is called whenever the sending status is updated for a particular mobile originated (MO) message.
	/// - parameter status: actual sending status for a MO message
	/// - parameter messageId: unique identifier of a MO message
	func update(messageSentStatus status: MM_MOMessageSentStatus, for messageId: MessageId, completion: @escaping () -> Void)
	
	/// This method is used to fetch and return all stored chat messages ids.
	/// - parameter completion: a block to be executed after fetching is completed, all the fetched message ids must be passed as a block parameter
	func findAllMessageIds(completion: @escaping ([String]) -> Void)
}

/// The adapter dispatches all adaptee method calls into the adaptee's queue,
/// and checks for existing messages to avoid duplications, that's all.
class MessageStorageQueuedAdapter: MMMessageStorage {
	
	let adapteeStorage: MMMessageStorage
	let messageFilter: (MMBaseMessage) -> Bool
	
	static func makeDefaultMessagesStoragaAdapter() -> MessageStorageQueuedAdapter? {
		if let s = MMDefaultMessageStorage.makeDefaultMessageStorage() {
			return MessageStorageQueuedAdapter.makeMessagesStoragaAdapter(storage: s)
		} else {
			return nil
		}
	}
	
	static func makeMessagesStoragaAdapter(storage: MMMessageStorage) -> MessageStorageQueuedAdapter {
		return MessageStorageQueuedAdapter(adapteeStorage: storage, messageFilter: { m in
			return !m.isChatMessage
		})
	}
	
	init(adapteeStorage: MMMessageStorage, messageFilter: @escaping (MMBaseMessage) -> Bool) {
		self.messageFilter = messageFilter
		self.adapteeStorage = adapteeStorage
	}
	
	@objc var queue: DispatchQueue {
		return adapteeStorage.queue
	}
	
	@objc func insert(outgoing messages: [MMBaseMessage], completion: @escaping () -> Void) {
		let messages = messages.filter(messageFilter)
		guard !messages.isEmpty else {
			completion()
			return
		}
		queue.async() {
			self.adapteeStorage.insert(outgoing: messages.filter({ return self.findMessage(withId: $0.messageId) == nil }), completion: completion)
		}
	}
	
	@objc func insert(incoming messages: [MMBaseMessage], completion: @escaping () -> Void) {
		let messages = messages.filter(messageFilter)
		guard !messages.isEmpty else {
			completion()
			return
		}
		queue.async() {
			self.adapteeStorage.insert(incoming: messages, completion: completion)
		}
	}
	
	@objc func findMessage(withId messageId: MessageId) -> MMBaseMessage? {
		return self.adapteeStorage.findMessage(withId: messageId)
	}
	
	@objc func findAllMessageIds(completion: @escaping ([String]) -> Void) {
		queue.async() {
			self.adapteeStorage.findAllMessageIds(completion: completion)
		}
	}
	
	@objc func update(messageSentStatus status: MM_MOMessageSentStatus, for messageId: MessageId, completion: @escaping () -> Void) {
		queue.async() {
			self.adapteeStorage.update(messageSentStatus: status, for: messageId, completion: completion)
		}
	}
	
	@objc func update(messageSeenStatus status: MMSeenStatus, for messageId: MessageId, completion: @escaping () -> Void) {
		queue.async() {
			self.adapteeStorage.update(messageSeenStatus: status, for: messageId, completion: completion)
		}
	}
	
	@objc func update(deliveryReportStatus isDelivered: Bool, for messageId: MessageId, completion: @escaping () -> Void) {
		queue.async() {
			self.adapteeStorage.update(deliveryReportStatus: isDelivered, for: messageId, completion: completion)
		}
	}
	
	@objc func start() {
		queue.async() {
			self.adapteeStorage.start()
		}
	}
	
	@objc func stop() {
		queue.async() {
			self.adapteeStorage.stop()
		}
	}
}
