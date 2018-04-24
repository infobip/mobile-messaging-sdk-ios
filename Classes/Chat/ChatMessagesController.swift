//
//  ChatMessagesController.swift
//  MobileChatExample
//
//  Created by Andrey Kadochnikov on 10/11/2017.
//  Copyright © 2017 Infobip d.o.o. All rights reserved.
//

import Foundation
import CoreData

extension NSFetchedResultsChangeType {
	var toChatMessagesChangeType: ChatMessagesChangeType {
		switch self {
		case .insert:
			return ChatMessagesChangeType.insert
		case .delete:
			return ChatMessagesChangeType.delete
		case .move:
			return ChatMessagesChangeType.move
		case .update:
			return ChatMessagesChangeType.update
		}
	}
}

@objc public enum ChatMessagesChangeType: UInt {
	case insert
	case delete
	case move
	case update
}

@objc public protocol ChatMessagesControllerDelegate {
	func controllerWillChangeContent(_ controller: ChatMessagesController)
	func controller(_ controller: ChatMessagesController, didChange message: ChatMessage, at indexPath: IndexPath?, for type: ChatMessagesChangeType, newIndexPath: IndexPath?)
	func controllerDidChangeContent(_ controller: ChatMessagesController)
}

/// Controller manages a fetched result controller bound with a private managed object context, it solves all the threading issues for the user, forwarding the fetched result controller delegate callbacks to the main queue. Also hides some internals from the user and simplifies access to messages.
@objc public class ChatMessagesController: NSObject, NSFetchedResultsControllerDelegate {
	public weak var delegate: ChatMessagesControllerDelegate? = nil
	let frc: NSFetchedResultsController<Message>
	
	init(frc: NSFetchedResultsController<Message>) {
		self.frc = frc
		super.init()
		self.frc.delegate = self
	}
	
	public func performFetch() {
		do {
			try frc.performFetch()
		} catch {
			MMLogError("[Chat messages controller] fetch error: \(error.localizedDescription)")
		}
	}
	
	public var fetchedMessagesCount: Int {
		return frc.fetchedObjects?.count ?? 0
	}
	
	public func chatMessage(at indexPath: IndexPath) -> ChatMessage? {
		let message = frc.object(at: indexPath)
		var ret: ChatMessage? = nil
		frc.managedObjectContext.performAndWait {
			ret = ChatMessage(message: message)
		}
		return ret
	}
	
	public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		guard let delegate = delegate else {
			return
		}
		OperationQueue.main.addOperation {
			delegate.controllerWillChangeContent(self)
		}
	}
	
	public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
		guard let delegate = delegate, let message = anObject as? Message, let chatMessage = ChatMessage(message: message) else {
			return
		}
		OperationQueue.main.addOperation {
			delegate.controller(self, didChange: chatMessage, at: indexPath, for: type.toChatMessagesChangeType, newIndexPath: newIndexPath)
		}
	}
	
	public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		guard let delegate = delegate else {
			return
		}
		OperationQueue.main.addOperation {
			delegate.controllerDidChangeContent(self)
		}
	}
}
