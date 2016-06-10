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

final class MessageHandlingOperation: GroupOperation {
	var context: NSManagedObjectContext
	var finishBlock: (NSError? -> Void)?
	var newMessageReceivedCallback: (() -> Void)? = nil
	var remoteAPIQueue: MMRemoteAPIQueue
	var userInfos: [[NSObject : AnyObject]]
	var messagesOrigin: MessageOrigin
	
	init(userInfos: [[NSObject : AnyObject]], messagesOrigin: MessageOrigin, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, newMessageReceivedCallback: (() -> Void)? = nil, finishBlock: (NSError? -> Void)? = nil) {
		self.userInfos = userInfos //can be either APNS or Server layout
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		self.messagesOrigin = messagesOrigin
		super.init(operations: [])
		
		self.userInitiated = true
		let messageHandling = BlockOperation(block: { block in
			self.handleMessage()
			block()
		})
		
		let reportDelivering = DeliveryReportingOperation(context: context, remoteAPIQueue: remoteAPIQueue)
		reportDelivering.addDependency(messageHandling)
		
		addOperation(messageHandling)
		addOperation(reportDelivering)
	}
	
	private func handleMessage() {
		context.performBlockAndWait {
			guard let newMessages: Set<MMMessage> = self.getNewMessages(self.context, userInfos: self.userInfos)
				where newMessages.count > 0
				else
			{
				return
			}
			
			for newMessage: MMMessage in newMessages {
				let newDBMessage = MessageManagedObject.MM_createEntityInContext(context: self.context)
				newDBMessage.messageId = newMessage.messageId
				newDBMessage.isSilent = newMessage.isSilent
			}
			
			self.context.MM_saveToPersistentStoreAndWait()
			
			self.postNewMessagesEvents(newMessages)
		}
	}
	
	private func postNewMessagesEvents(newMessages: Set<MMMessage>) {
		MMQueue.Main.queue.executeAsync {
			for newMessage in newMessages {
				if let payload = newMessage.payload {
					NSNotificationCenter.defaultCenter().postNotificationName(MMEventNotifications.kMessageReceived,
											object: self,
											userInfo: [
													MMEventNotificationKeys.kMessagePayloadKey: payload,
													MMEventNotificationKeys.kMessageIsPushKey: self.messagesOrigin == .APNS,
													MMEventNotificationKeys.kMessageIsSilentKey: newMessage.isSilent
													])
				}
				self.newMessageReceivedCallback?()
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
		finishBlock?(errors.first)
	}
}
