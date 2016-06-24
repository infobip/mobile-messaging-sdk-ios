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

final class MessageHandlingOperation: Operation {
	var context: NSManagedObjectContext
	var finishBlock: (NSError? -> Void)?
	var newMessageReceivedCallback: ([NSObject : AnyObject] -> Void)? = nil
	var remoteAPIQueue: MMRemoteAPIQueue
	var userInfos: [[NSObject : AnyObject]]
	var messagesOrigin: MessageOrigin
	var hasNewMessages: Bool = false
	
	init(userInfos: [[NSObject : AnyObject]], messagesOrigin: MessageOrigin, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, newMessageReceivedCallback: ([NSObject : AnyObject] -> Void)? = nil, finishBlock: (NSError? -> Void)? = nil) {
		self.userInfos = userInfos //can be either APNS or Server layout
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
			guard let newMessages: Set<MMMessage> = self.getNewMessages(self.context, userInfos: self.userInfos)
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
			}
			
			self.context.MM_saveToPersistentStoreAndWait()
			
			self.postNewMessagesEvents(newMessages)
			
			self.finish()
		}
	}
	
	private func postNewMessagesEvents(newMessages: Set<MMMessage>) {
		MMQueue.Main.queue.executeAsync {
			for newMessage in newMessages {
				if let payload = newMessage.payload {
					let userInfo: [NSObject : AnyObject] = [ MMNotificationKeyMessagePayload: payload, MMNotificationKeyMessageIsPush: self.messagesOrigin == .APNS, MMNotificationKeyMessageIsSilent: newMessage.isSilent ]
					NSNotificationCenter.defaultCenter().postNotificationName(MMNotificationMessageReceived, object: self, userInfo: userInfo)
					self.newMessageReceivedCallback?(userInfo)
				}
			}
		}
	}
	
	private func getNewMessages(context: NSManagedObjectContext, userInfos: [[NSObject : AnyObject]]) -> Set<MMMessage>? {
		guard userInfos.count > 0 else {
			return nil
		}
		let messagesSet = Set(userInfos.flatMap(MMMessage.init))
		var dbMessages = [MMMessage]()
		if let msgs = MessageManagedObject.MM_findAllInContext(context) as? [MessageManagedObject] {
			dbMessages = msgs.map(MMMessage.init)
		}
		let dbMessagesSet = Set(dbMessages)
		return messagesSet.subtract(dbMessagesSet)
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
