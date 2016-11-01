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
	var messagesToSend: Set<MOMessage>?
	var resultMessages: [MOMessage]?
	
	init(messages: [MOMessage]?, context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (MMMOMessageResult -> Void)? = nil) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		if let messages = messages where !messages.isEmpty {
			self.messagesToSend = Set(messages)
		}
		super.init()
	}
	
	override func execute() {
		guard let internalId = MobileMessaging.currentUser?.internalId else {
			self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		guard let messagesToSend = self.messagesToSend where !messagesToSend.isEmpty else {
			self.finish()
			return
		}
		self.context.performBlockAndWait {
			if let request = MMPostMessageRequest(internalUserId: internalId, messages: Array(messagesToSend)) {
				self.postWillSendNotification(messagesToSend: messagesToSend)
				self.populateMessageStorage(with: messagesToSend)
				self.remoteAPIQueue.perform(request: request) { result in
					self.handleResult(result)
				}
			}
		}
	}
	
	private func populateMessageStorage(with messages: Set<MOMessage>) {
		MobileMessaging.sharedInstance?.messageStorageAdapter?.insert(outgoing: Array(messages))
	}
	
	private func updateMessageStorage(with messages: [MOMessage]) {
		messages.forEach({ MobileMessaging.sharedInstance?.messageStorageAdapter?.update(messageSentStatus: $0.sentStatus, for: $0.messageId) })
	}
	
	private func postWillSendNotification(messagesToSend messagesToSend: Set<MOMessage>) {
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
				self.updateMessageStorage(with: response.messages)
				MMLogDebug("Message posting successfuly finished")
			case .Failure(let error):
				MMLogError("Message posting request failed with error: \(error)")
			case .Cancel:
				MMLogError("Message posting cancelled")
			}
		}
		self.finishWithError(result.error)
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
