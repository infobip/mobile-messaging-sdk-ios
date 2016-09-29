//
//  MessageHandlingOperation.swift
//
//  Created by Andrey K. on 20/04/16.
//
//

import UIKit
import CoreData

@objc public enum MessageOrigin: Int {
	case APNS, Server
}

func == (lhs: MessageMeta, rhs: MessageMeta) -> Bool {
	return lhs.hashValue == rhs.hashValue
}

struct MessageMeta : MMMessageMetadata {
	var isSilent: Bool
	var messageId: String
	
	var hashValue: Int {
		return messageId.hash
	}
	
	init(message: MessageManagedObject) {
		self.messageId = message.messageId
		self.isSilent = message.isSilent.boolValue
	}
	
	init(message: MMMessage) {
		self.messageId = message.messageId
		self.isSilent = message.isSilent
	}
}

final class MessageHandlingOperation: Operation {
	var context: NSManagedObjectContext
	var finishBlock: (NSError? -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	var messagesToHandle: [MMMessage]
	var messagesOrigin: MessageOrigin
	var hasNewMessages: Bool = false
	var messageHandler: MessageHandling
	
	init(messagesToHandle: [MMMessage], messagesOrigin: MessageOrigin, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, messageHandler: MessageHandling, finishBlock: (NSError? -> Void)? = nil) {
		self.messagesToHandle = messagesToHandle //can be either native APNS or custom Server layout
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		self.messagesOrigin = messagesOrigin
		self.messageHandler = messageHandler
		super.init()
		
		self.userInitiated = true
	}
	
	override func execute() {
		MMLogDebug("Starting message handling operation...")
		context.performBlockAndWait {
			guard let newMessages: [MMMessage] = self.getNewMessages(self.context, messagesToHandle: self.messagesToHandle) where !newMessages.isEmpty else
			{
				MMLogDebug("There is no new messages to handle.")
				self.finish()
				return
			}
			self.hasNewMessages = true
			MMLogDebug("There are \(newMessages.count) new messages to handle.")
			for newMessage: MMMessage in newMessages {
				let newDBMessage = MessageManagedObject.MM_createEntityInContext(context: self.context)
				newDBMessage.messageId = newMessage.messageId
				newDBMessage.isSilent = newMessage.isSilent
				
				// Add new regions for geofencing
				if let geoService = MMGeofencingService.sharedInstance where geoService.isRunning,
					let geoMessage = newMessage as? MMGeoMessage {
					newDBMessage.payload = newMessage.originalPayload
					newDBMessage.messageType = .Geo
					geoService.add(message: geoMessage)
				}
			}
			self.context.MM_saveToPersistentStoreAndWait()
			
			self.handle(newMessages: newMessages)
			
			self.finish()
		}
	}
	
	private func handle(newMessages messages: [MMMessage]) {
		MMQueue.Main.queue.executeAsync {
			messages.forEach { message in
				self.messageHandler.didReceiveNewMessage(message)
				self.postNotificationForObservers(with: message)
			}
		}
	}
	
	private func postNotificationForObservers(with message: MMMessage) {
		var userInfo: [NSObject: AnyObject] = [ MMNotificationKeyMessage: message, MMNotificationKeyMessagePayload: message.originalPayload, MMNotificationKeyMessageIsPush: message.origin == .APNS, MMNotificationKeyMessageIsSilent: message.isSilent ]
		if let customPayload = message.customPayload {
			userInfo[MMNotificationKeyMessageCustomPayload] = customPayload
		}
		NSNotificationCenter.defaultCenter().postNotificationName(MMNotificationMessageReceived, object: self, userInfo: userInfo)
	}
	
	private func getNewMessages(context: NSManagedObjectContext, messagesToHandle: [MMMessage]) -> [MMMessage]? {
		guard messagesToHandle.count > 0 else {
			return nil
		}
		let messagesSet = Set(messagesToHandle.flatMap(MessageMeta.init))
		var dbMessages = [MessageMeta]()
		if let msgs = MessageManagedObject.MM_findAllInContext(context) as? [MessageManagedObject] {
			dbMessages = msgs.map(MessageMeta.init)
		}
		let dbMessagesSet = Set(dbMessages)
		let newMessageMetas = messagesSet.subtract(dbMessagesSet)
		return newMessageMetas.flatMap(metaToMessage)
	}
	
	private func metaToMessage(meta: MessageMeta) -> MMMessage? {
		if let message = self.messagesToHandle.filter({ (msg: MMMessage) -> Bool in
			return msg.messageId == meta.messageId
		}).first {
			return message
		} else {
			return nil
		}
	}
	
	override func finished(errors: [NSError]) {
		MMLogDebug("Message handling finished with errors: \(errors)")
		if hasNewMessages && errors.isEmpty {
			let messageFetching = MessageFetchingOperation(context: context, remoteAPIQueue: remoteAPIQueue, finishBlock: { result in
				self.finishBlock?(result.error)
			})
			self.produceOperation(messageFetching)
		} else {
			self.finishBlock?(errors.first)
		}
	}
}

public class MMDefaultMessageHandling: MessageHandling {
	@objc public func didReceiveNewMessage(message: MMMessage) {
		if message.origin == .Server && !message.isSilent {
			self.presentLocalNotificationAlert(with: message)
		}
	}
	
	func presentLocalNotificationAlert(with message: MMMessage) {
		MMLocalNotification.presentLocalNotification(with: message)
	}
}