//
//  StorageProtocols.swift
//
//  Created by Andrey K. on 15/09/16.
//

import Foundation

public typealias MessageId = String
public typealias FetchResultBlock = ([BaseMessage]?) -> Void

/// The class defines a query that is used to fetch messages from the Message Storage.
@objc public class Query: NSObject {
	/// A limit on the number of objects to return. The default limit is undefined (unlimited).
	public var limit: Int?
	
	/// The number of objects to skip before returning any. The default value is 0.
	public var skip: Int?
	
	/// The following types of predicates are supported:
	/// - Simple comparisons such as `=`, `!=`, `<`, `>`, `<=`, `>=`, and `BETWEEN` with a key and a constant.
	/// - Containment predicates, such as `x IN {1, 2, 3}`.
	/// - Key-existence predicates, such as `x IN SELF`.
	/// - BEGINSWITH expressions.
	/// - Compound predicates with `AND`, `OR`, and `NOT`.
	/// - SubQueries with `key IN %@`, subquery.
	///
	/// The following types of predicates are NOT supported:
	/// - Aggregate operations, such as `ANY`, `SOME`, `ALL`, or `NONE`.
	/// - Regular expressions, such as `LIKE`, `MATCHES`, `CONTAINS`, or `ENDSWITH`.
	/// - Predicates comparing one key to another.
	/// - Complex predicates with many ORed clauses.
	public var predicate: NSPredicate?
	
	/// An array of `NSSortDescriptor` objects to use to sort the results of the query.
	public var sortDescriptors: [NSSortDescriptor]?
	
	override init() {
		super.init()
	}
}

@objc public protocol MessageStorageDelegate {
	func didInsertNewMessages(_ messages: [BaseMessage])
	func didUpdateMessage(_ message: BaseMessage)
	func didRemoveMessages(_ messages: [BaseMessage])
}

@objc public protocol MessageStorageFinders {
	func findAllMessages(completion: @escaping FetchResultBlock)
	func findMessages(withIds messageIds: [MessageId], completion: @escaping FetchResultBlock)
	func findMessages(withQuery query: Query, completion: @escaping FetchResultBlock)
}

@objc public protocol MessageStorageRemovers {
	func removeAllMessages()
	func remove(withIds messageIds: [MessageId])
	func remove(withQuery query: Query)
}

/// The protocol describes implementation of the Message Storage. The Message Storage persists all the messages (both mobile originated and mobile terminated).
@objc public protocol MessageStorage {
	/// The queue in which all the hooks(inserts, updates) are dispatched.
	/// The queue must be provided by the particular implementation of this protocol in order to provide thread safety and performance aspects.
	var queue: DispatchQueue {get}
	
	/// This method is called by the Mobile Messaging SDK during the initialization process. You implement your custom preparation routine here if needed.
	func start()
	
	/// This method is called by the Mobile Messaging SDK while stopping the currently running session (see also `MobileMessaging.stop()` method). You implement your custom deinitialization routine here if needed.
	func stop()
	
	/// This method is called whenever a new mobile originated message is about to be sent to the server.
	func insert(outgoing messages: [MOMessage], completion: @escaping () -> Void)
	
	/// This method is called whenever a new mobile terminated message (either push(remote) notifictaion or fetched message) is received by the Mobile Messaging SDK.
	func insert(incoming messages: [MTMessage], completion: @escaping () -> Void)
	
	/// This method is used by the Mobile Messaging SDK in order to detect duplicated messages persisted in the Message Storage. It is strongly recommended to implement this method in your custom Message Storage.
	/// - parameter messageId: unique identifier of a MT message. Consider this identifier as a primary key.
	func findMessage(withId messageId: MessageId) -> BaseMessage?
	
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
	func update(messageSentStatus status: MOMessageSentStatus, for messageId: MessageId, completion: @escaping () -> Void)
}

/// The adapter dispatches all adaptee method calls into the adaptee's queue,
/// and checks for existing messages to avoid duplications, that's all.
class MMMessageStorageQueuedAdapter: MessageStorage {

	let adapteeStorage: MessageStorage
	
	init?(adapteeStorage: MessageStorage?) {
		guard let adapteeStorage = adapteeStorage else {
			return nil
		}
		self.adapteeStorage = adapteeStorage
	}
	
	@objc var queue: DispatchQueue {
		return adapteeStorage.queue
	}
	
	@objc func insert(outgoing messages: [MOMessage], completion: @escaping () -> Void) {
		guard !messages.isEmpty else {
			completion()
			return
		}
		queue.async() {
			self.adapteeStorage.insert(outgoing: messages.filter({ return self.findMessage(withId: $0.messageId) == nil }), completion: completion)
		}
	}
	
	@objc func insert(incoming messages: [MTMessage], completion: @escaping () -> Void) {
		guard !messages.isEmpty else {
			completion()
			return
		}
		queue.async() {
			self.adapteeStorage.insert(incoming: messages, completion: completion)
		}
	}
	
	@objc func findMessage(withId messageId: MessageId) -> BaseMessage? {
		return self.adapteeStorage.findMessage(withId: messageId)
	}
	
	@objc func update(messageSentStatus status: MOMessageSentStatus, for messageId: MessageId, completion: @escaping () -> Void) {
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
