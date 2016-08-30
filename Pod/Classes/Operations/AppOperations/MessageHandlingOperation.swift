//
//  MessageHandlingOperation.swift
//
//  Created by Andrey K. on 20/04/16.
//
//

import UIKit
import CoreData

enum MessageOrigin {
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
	var finishBlock: ((NSError?) -> Void)?
	var newMessageReceivedCallback: (([AnyHashable : Any]) -> Void)? = nil
	var remoteAPIQueue: MMRemoteAPIQueue
	var messagesToHandle: [MMMessage]
	var messagesOrigin: MessageOrigin
	var hasNewMessages: Bool = false
	
	init(messagesToHandle: [MMMessage], messagesOrigin: MessageOrigin, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, newMessageReceivedCallback: (([AnyHashable : Any]) -> Void)? = nil, finishBlock: ((NSError?) -> Void)? = nil) {
		self.messagesToHandle = messagesToHandle //can be either native APNS or custom Server layout
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		self.messagesOrigin = messagesOrigin
		self.newMessageReceivedCallback = newMessageReceivedCallback
		super.init()
		
		self.userInitiated = true
	}
	
	override func execute() {
		MMLogDebug("Starting message handling operation...")
		handleMessage()
	}
	
	private func handleMessage() {
		context.performAndWait {
			guard let newMessages: [MMMessage] = self.getNewMessages(context: self.context, messagesToHandle: self.messagesToHandle) , !newMessages.isEmpty else
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
				newDBMessage.isSilent = NSNumber(value: newMessage.isSilent)

                // Add new regions for geofencing
				if MMGeofencingService.sharedInstance.isRunning {
					if let newCampaing = MMCampaign(message: newMessage) {
						MMGeofencingService.sharedInstance.addCampaingToRegionMonitoring(newCampaing)
					}
				}
			}
			self.context.MM_saveToPersistentStoreAndWait()
			
			self.postNewMessagesEvents(newMessages: newMessages)
			
			self.finish()
		}
	}
	
	private func postNewMessagesEvents(newMessages: [MMMessage]) {
		MMQueue.Main.queue.executeAsync {
			for msg in newMessages {
				var userInfo: [AnyHashable : Any] = [MMNotificationKeyMessagePayload: msg.originalPayload,
				                                     MMNotificationKeyMessageIsSilent: msg.isSilent,
				                                     MMNotificationKeyMessageIsPush: self.messagesOrigin == .APNS]
				if let customPayload = msg.customPayload {
					userInfo[MMNotificationKeyMessageCustomPayload] = customPayload
				}

				NotificationCenter.default.post(name: NSNotification.Name(rawValue: MMNotificationMessageReceived), object: self, userInfo: userInfo)
				self.newMessageReceivedCallback?(userInfo)
			}
		}
	}
	
	private func getNewMessages(context: NSManagedObjectContext, messagesToHandle: [MMMessage]) -> [MMMessage]? {
		guard messagesToHandle.count > 0 else {
			return nil
		}
		var messagesSet = Set(messagesToHandle.flatMap(MessageMeta.init))
		var dbMessages = [MessageMeta]()
		if let msgs = MessageManagedObject.MM_findAllInContext(context) {
			dbMessages = msgs.map(MessageMeta.init)
		}
		let dbMessagesSet = Set(dbMessages)
		messagesSet.subtract(dbMessagesSet)
		return messagesSet.flatMap(metaToMessage)
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
	
	override func finished(_ errors: [NSError]) {
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
