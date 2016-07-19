//
//  MessageHandlingOperation.swift
//  Pods
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
	var finishBlock: (NSError? -> Void)?
	var newMessageReceivedCallback: ([NSObject : AnyObject] -> Void)? = nil
	var remoteAPIQueue: MMRemoteAPIQueue
	var messagesToHandle: [MMMessage]
	var messagesOrigin: MessageOrigin
	var hasNewMessages: Bool = false
	
	init(messagesToHandle: [MMMessage], messagesOrigin: MessageOrigin, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, newMessageReceivedCallback: ([NSObject : AnyObject] -> Void)? = nil, finishBlock: (NSError? -> Void)? = nil) {
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
		handleMessage()
	}
	
	private func handleMessage() {
		context.performBlockAndWait {
			guard let newMessages: [MMMessage] = self.getNewMessages(self.context, messagesToHandle: self.messagesToHandle)
				where newMessages.count > 0
				else
			{
				self.finish()
				return
			}
			self.hasNewMessages = true
			
			for newMessage: MMMessage in newMessages {
				let newDBMessage = MessageManagedObject.MM_createEntityInContext(context: self.context)
				newDBMessage.messageId = newMessage.messageId
				newDBMessage.isSilent = newMessage.isSilent
                
                // Add new regions for geofencing
                if let geoData = newMessage.geoData {
                    let newCampaing = MMLocationManager.getCampaignFromDictionary(geoData)
                    MMLocationManager.sharedInstance.addCampaingToRegionMonitoring(newCampaing)
                }
			}
			self.context.MM_saveToPersistentStoreAndWait()
			
			self.postNewMessagesEvents(newMessages)
			
			self.finish()
		}
	}
	
	private func postNewMessagesEvents(newMessages: [MMMessage]) {
		MMQueue.Main.queue.executeAsync {
			for msg in newMessages {
				var userInfo: [NSObject : AnyObject] = [ MMNotificationKeyMessagePayload: msg.originalPayload, MMNotificationKeyMessageIsPush: self.messagesOrigin == .APNS, MMNotificationKeyMessageIsSilent: msg.isSilent ]
				if let customPayload = msg.customPayload {
					userInfo[MMNotificationKeyMessageCustomPayload] = customPayload
				}
				NSNotificationCenter.defaultCenter().postNotificationName(MMNotificationMessageReceived, object: self, userInfo: userInfo)
				self.newMessageReceivedCallback?(userInfo)
			}
		}
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
		if hasNewMessages && errors.isEmpty {
			let syncOperation = SyncOperation(context: context, remoteAPIQueue: remoteAPIQueue, finishBlock: { result in
				self.finishBlock?(result.error)
			})
			self.produceOperation(syncOperation)
		} else {
			self.finishBlock?(errors.first)
		}
	}
}
