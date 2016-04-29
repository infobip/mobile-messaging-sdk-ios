//
//  MessageHandlingOperation.swift
//  Pods
//
//  Created by Andrey K. on 20/04/16.
//
//

import UIKit
import CoreData

class MessageHandlingOperation: GroupOperation {
	var context: NSManagedObjectContext
	var finishBlock: (NSError? -> Void)?
	var newMessageReceivedCallback: (() -> Void)? = nil
	var remoteAPIQueue: MMRemoteAPIQueue
	var userInfos: [[NSObject : AnyObject]]
	
	init(userInfos: [[NSObject : AnyObject]], context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, newMessageReceivedCallback: (() -> Void)? = nil, finishBlock: (NSError? -> Void)? = nil) {
		self.userInfos = userInfos
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		
		super.init(operations: [])
		
		self.userInitiated = true
		let messageHandling = BlockOperation(block: { block in
			self.messageHandling()
			block()
		})
		
		let reportDelivering = DeliveryReportingOperation(context: context, remoteAPIQueue: remoteAPIQueue)
		reportDelivering.addDependency(messageHandling)
		
		addOperation(messageHandling)
		addOperation(reportDelivering)
	}
	
	private func messageHandling() {
		context.performBlockAndWait {
			guard let newMessages = self.getNewMessages(self.context, userInfos: self.userInfos)
				where newMessages.count > 0
				else
			{
				return
			}
			
			for newMessage in newMessages {
				let newDBMessage = MessageManagedObject.MR_createEntityInContext(self.context)
				newDBMessage.messageId = newMessage.messageId
				newDBMessage.supplementaryId = newMessage.supplementaryId
				newDBMessage.creationDate = NSDate()
			}
			
			self.context.MR_saveToPersistentStoreAndWait()
			
			self.postNewMessagesEvents(newMessages)
		}
	}
	
	private func postNewMessagesEvents(newMessages: Set<MMMessage>) {
		MMQueue.Main.queue.executeAsync {
			for newMessage in newMessages {
				if let payload = newMessage.payload {
					NSNotificationCenter.defaultCenter().postNotificationName(MMEventNotifications.kMessageReceived, object: self, userInfo: [MMEventNotifications.kMessageUserInfoKey: payload])
				}
				self.newMessageReceivedCallback?()
			}
		}
	}
	
	private func getNewMessages(context: NSManagedObjectContext, userInfos: [[NSObject : AnyObject]]) -> Set<MMMessage>? {
		guard userInfos.count > 0
			else {
			return nil
		}
		let messagesSet = Set(userInfos.flatMap(MMMessage.init))
		var dbMessages = [MMMessage]()
		if let msgs = MessageManagedObject.MR_findAllInContext(context) as? [MessageManagedObject] {
			dbMessages = msgs.map(MMMessage.init)
		}
		let dbMessagesSet = Set(dbMessages)
		return messagesSet.subtract(dbMessagesSet)
	}
	
	override func finished(errors: [NSError]) {
		finishBlock?(errors.first)
	}
}
