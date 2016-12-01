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
	let finishBlock: ((MOMessageSendingResult) -> Void)?
	var result = MOMessageSendingResult.Cancel
	var messagesToSend: Set<MOMessage>?
	var resultMessages: [MOMessage]?
	
	init(messages: [MOMessage]?, context: NSManagedObjectContext, finishBlock: ((MOMessageSendingResult) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		if let messages = messages, !messages.isEmpty {
			self.messagesToSend = Set(messages)
		}
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Message posting] started...")
		guard let internalId = MobileMessaging.currentUser?.internalId else {
			self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		guard let messagesToSend = self.messagesToSend, !messagesToSend.isEmpty else {
			self.finish()
			return
		}
		self.context.performAndWait {
			self.postWillSendNotification(messagesToSend: messagesToSend)
			self.populateMessageStorage(with: messagesToSend)
			
			MobileMessaging.sharedInstance?.remoteApiManager.sendMessages(internalUserId: internalId, messages: Array(messagesToSend)) { result in
				self.handleResult(result: result)
			}
		}
	}
	
	private func populateMessageStorage(with messages: Set<MOMessage>) {
		MobileMessaging.sharedInstance?.messageStorageAdapter?.insert(outgoing: Array(messages))
	}
	
	private func updateMessageStorage(with messages: [MOMessage]) {
		messages.forEach({ MobileMessaging.sharedInstance?.messageStorageAdapter?.update(messageSentStatus: $0.sentStatus, for: $0.messageId) })
	}
	
	private func postWillSendNotification(messagesToSend: Set<MOMessage>) {
		var userInfo = DictionaryRepresentation()

		userInfo[MMNotificationKeyMessageSendingMOMessages] = messagesToSend
		NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationMessagesWillSend, userInfo: userInfo.isEmpty ? nil : userInfo)
	}
	
	private func postDidSendNotification(resultMessages: [MOMessage]) {
		var userInfo = DictionaryRepresentation()
		userInfo[MMNotificationKeyMessageSendingMOMessages] = resultMessages
		NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationMessagesDidSend, userInfo: userInfo.isEmpty ? nil : userInfo)
	}
	
	private func handleResult(result: MOMessageSendingResult) {
		self.result = result
		context.performAndWait {
			switch result {
			case .Success(let response):
				self.handleSuccess(messages: response.messages)
				self.updateMessageStorage(with: response.messages)
				MMLogDebug("[Message posting] successfuly finished")
			case .Failure(let error):
				MMLogError("[Message posting] request failed with error: \(error)")
			case .Cancel:
				MMLogError("[Message posting] cancelled")
			}
		}
		self.finishWithError(result.error)
	}
	
	private func handleSuccess(messages : [MOMessage]) {
		resultMessages = messages
		self.postDidSendNotification(resultMessages: messages)
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Message posting] finished with errors: \(errors)")
		let finishResult = errors.isEmpty ? result : MOMessageSendingResult.Failure(errors.first)
		finishBlock?(finishResult)
	}
}
