//
//  MessagePostingOperation.swift
//
//  Created by Andrey K. on 19/07/16.
//
//

import UIKit
import CoreData

class MessagePostingOperation: Operation {
	let context: NSManagedObjectContext
	let finishBlock: (MMMOMessageResult -> Void)?
	var result = MMMOMessageResult.Cancel
	let remoteAPIQueue: MMRemoteAPIQueue
	var messagesToSend: [MOMessage]?
	var resultMessages: [MOMessage]?
	
	init(messages: [MOMessage]?, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (MMMOMessageResult -> Void)? = nil) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		self.messagesToSend = messages
		super.init()
		
		self.addCondition(RegistrationCondition(internalId: MobileMessaging.currentUser?.internalId))
	}
	
	override func execute() {
		self.context.performBlockAndWait {
			
			guard let internalId = MobileMessaging.currentUser?.internalId else {
				self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
				return
			}
			
			guard let messagesToSend = self.messagesToSend else {
				self.finish()
				return
			}
			
			if let request = MMPostMessageRequest(internalUserId: internalId, messages: messagesToSend) {
				
				self.postWillSendNotification(messagesToSend: messagesToSend)
				
				self.remoteAPIQueue.perform(request: request) { result in
					self.handleResult(result)
					self.finishWithError(result.error)
				}
			}
		}
	}
	
	private func postWillSendNotification(messagesToSend messagesToSend: [MOMessage]) {
		var userInfo = [String: AnyObject]()
		userInfo[MMNotificationKeyMessageSendingMOMessages] = messagesToSend
		NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationMessagesWillSend, userInfo: userInfo.isEmpty ? nil : userInfo)
	}
	
	private func postDidSendNotification(resultMessages: [MOMessage]) {
		var userInfo = [String: AnyObject]()
		userInfo[MMNotificationKeyMessageSendingMOMessages] = resultMessages
		NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationMessagesDidSend, userInfo: userInfo.isEmpty ? nil : userInfo)
	}
	
	private func handleResult(result: MMMOMessageResult) {
		self.result = result
		context.performBlockAndWait {
			switch result {
			case .Success(let response):
				self.handleSuccess(response.messages)
				MMLogDebug("Message posting successfuly finished")
			case .Failure(let error):
				MMLogError("Message posting request failed with error: \(error)")
				return
			case .Cancel:
				MMLogError("Message posting cancelled")
				return
			}
		}
	}
	
	private func handleSuccess(messages : [MOMessage]) {
		resultMessages = messages
		self.postDidSendNotification(messages)
	}
	
	override func finished(errors: [NSError]) {
		let finishResult = errors.isEmpty ? result : MMMOMessageResult.Failure(errors.first)
		finishBlock?(finishResult)
	}
}
