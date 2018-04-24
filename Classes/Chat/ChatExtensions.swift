//
//  ChatExtensions.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 08/11/2017.
//

import Foundation
import CoreData

extension MobileMessaging {
	
	/// This service manages Mobile Chat, provides API for sending and receiving mobile chat messages.
	///
	/// You access the Mobile Chat service APIs through this property.
	public class var mobileChat: MobileChat? {
		if MobileChat.sharedInstance == nil {
			guard let defaultContext = MobileMessaging.sharedInstance, let storage = MMDefaultChatStorage.makeDefaultChatStorage() else {
				return nil
			}
			MobileChat.sharedInstance = MobileChat(mmContext: defaultContext, storage: storage)
		}
		return MobileChat.sharedInstance
	}
	
	/// Fabric method for Mobile Messaging session.
	/// Use this method to enable the Mobile Chat service with default message storage implementation.
	public func withMobileChat() -> MobileMessaging {
		if MobileChat.sharedInstance == nil {
			if let defaultContext = MobileMessaging.sharedInstance, let storage = MMDefaultChatStorage.makeDefaultChatStorage()
			{
				MobileChat.sharedInstance = MobileChat(mmContext: defaultContext, storage: storage)
			}
		}
		return self
	}
	
	/// Fabric method for Mobile Messaging session.
	/// Use this method to enable the Mobile Chat service with a your custom message storage implementation.
	public func withMobileChat(storage: MessageStorage) -> MobileMessaging {
		if MobileChat.sharedInstance == nil {
			if let defaultContext = MobileMessaging.sharedInstance {
				MobileChat.sharedInstance = MobileChat(mmContext: defaultContext, storage: storage)
			}
		}
		return self
	}
	
	var chatStorage: MessageStorage? {
		get {
			return messageStorages[MessageStorageKind.chat.rawValue]?.adapteeStorage
		}
		set {
			if let newValue = newValue {
				messageStorages[MessageStorageKind.chat.rawValue] = MessageStorageQueuedAdapter.makeChatStoragaAdapter(storage: newValue)
			} else {
				messageStorages[MessageStorageKind.chat.rawValue] = nil
			}
		}
	}
}

@objc public class MMDefaultChatStorage: MMDefaultMessageStorage {
	private var _fetchedResultController: NSFetchedResultsController<Message>? = nil
	public var fetchedResultController: NSFetchedResultsController<Message>? {
		guard let context = self.context else {
			return nil
		}
		if _fetchedResultController == nil {
			let req = NSFetchRequest<Message>(entityName: "Message")
			req.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: true)]
			req.fetchBatchSize = 10
			_fetchedResultController = NSFetchedResultsController<Message>(fetchRequest: req, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
		}
		return _fetchedResultController
	}
	
	static func makeDefaultChatStorage() -> MMDefaultChatStorage? {
		if let s = try? MMCoreDataStorage.makeSQLiteChatStorage() {
			return MMDefaultChatStorage(coreDataStorage: s)
		} else {
			MMLogError("Mobile messaging failed to initialize default chat storage")
			return nil
		}
	}
}

extension MessageStorageQueuedAdapter {
	static func makeDefaultChatStoragaAdapter() -> MessageStorageQueuedAdapter? {
		if let s =  MMDefaultChatStorage.makeDefaultChatStorage() {
			return MessageStorageQueuedAdapter.makeChatStoragaAdapter(storage: s)
		} else {
			return nil
		}
	}
	
	static func makeChatStoragaAdapter(storage: MessageStorage) -> MessageStorageQueuedAdapter {
		return MessageStorageQueuedAdapter(adapteeStorage: storage, messageFilter: { m in
			return m.isChatMessage
		})
	}
}
