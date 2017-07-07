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
	let mmContext: MobileMessaging
	
	init(messages: [MOMessage]?, context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: ((MOMessageSendingResult) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		if let messages = messages, !messages.isEmpty {
			self.messagesToSend = Set(messages)
		}
		self.mmContext = mmContext
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Message posting] started...")
		guard let internalId = mmContext.currentUser?.internalId else
        {
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		
		guard let messagesToSend = messagesToSend, !messagesToSend.isEmpty else
        {
			finish()
			return
		}
		
		context.reset()
		context.performAndWait {
			self.postWillSendNotification(messagesToSend: messagesToSend)
			self.populateMessageStorage(with: messagesToSend) {
				self.mmContext.remoteApiManager.sendMessages(internalUserId: internalId, messages: Array(messagesToSend)) { result in
					self.result = result
					self.handleResult(result: result) {
						self.finishWithError(result.error)
					}
				}
			}
		}
	}
	
	private func populateMessageStorage(with messages: Set<MOMessage>, completion: @escaping () -> Void) {
		guard let storage = mmContext.messageStorageAdapter else {
			completion()
			return
		}
		storage.insert(outgoing: Array(messages), completion: completion)
	}
	
	private func updateMessageStorage(with messages: [MOMessage], completion: @escaping () -> Void) {
		guard let storage = mmContext.messageStorageAdapter, !messages.isEmpty else {
			completion()
			return
		}
		storage.batchSentStatusUpdate(messages: messages, completion: completion)
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
	
	private func handleResult(result: MOMessageSendingResult, completion: @escaping () -> Void) {
		context.performAndWait {
			switch result {
			case .Success(let response):
				self.resultMessages = response.messages
				self.updateMessageStorage(with: response.messages) {
					self.postDidSendNotification(resultMessages: response.messages)
					completion()
				}
				MMLogDebug("[Message posting] successfuly finished")
			case .Failure(let error):
				MMLogError("[Message posting] request failed with error: \(String(describing: error))")
				completion()
			case .Cancel:
				MMLogError("[Message posting] cancelled")
				completion()
			}
		}
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Message posting] finished with errors: \(errors)")
		let finishResult = errors.isEmpty ? result : MOMessageSendingResult.Failure(errors.first)
		finishBlock?(finishResult)
	}
}
