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
	let messages: Set<MOMessage>?
	let mmContext: MobileMessaging
	let isUserInitiated: Bool
	var sentMessageObjectIds = [NSManagedObjectID]()
	var operationResult = MOMessageSendingResult.Cancel
	
	init(messages: [MOMessage]?, isUserInitiated: Bool, context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: ((MOMessageSendingResult) -> Void)? = nil) {
		self.isUserInitiated = isUserInitiated
		self.context = context
		self.finishBlock = finishBlock
		if let messages = messages, !messages.isEmpty {
			self.messages = Set(messages)
		} else {
			self.messages = nil
		}
		self.mmContext = mmContext
		super.init()
	}
	
	override func execute() {
		MMLogDebug("[Message posting] started...")
		guard let internalId = mmContext.currentUser?.pushRegistrationId else {
			MMLogDebug("[Message posting] No registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		guard mmContext.apnsRegistrationManager.isRegistrationHealthy else {
			MMLogDebug("[Message posting] Registration may be not healthy. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}
		
		context.reset()
		context.performAndWait {
			let messagesToSend: [MOMessage]
			
			// if there were explicit messages to send
			if let messages = self.messages {
				
				// new messages sending
				messagesToSend = MessagePostingOperation.findNewMOMessages(among: messages, inContext: self.context)
				
				// if not user-initiated we must guarantee retries, thus persist the MOs
				if !self.isUserInitiated {
					messagesToSend.forEach { originalMessage in
						let newDBMessage = MessageManagedObject.MM_createEntityInContext(context: self.context)
						newDBMessage.messageId = originalMessage.messageId
						newDBMessage.isSilent = false
						newDBMessage.reportSent = false
						newDBMessage.deliveryReportedDate = nil
						newDBMessage.messageType = .MO
						newDBMessage.payload = originalMessage.originalPayload
						newDBMessage.creationDate = originalMessage.composedDate
						do { try self.context.obtainPermanentIDs(for: [newDBMessage]) } catch (_) { }
						self.sentMessageObjectIds.append(newDBMessage.objectID)
					}
					self.context.MM_saveToPersistentStoreAndWait()
				}
				
				MMLogDebug("[Message posting] posting new MO messages...")
				self.populateMessageStorageIfNeeded(with: messagesToSend) {
					self.sendMessages(Array(messagesToSend), internalId: internalId)
				}
			} else {
				// let's send persisted messages (retries)
				let mmos = MessagePostingOperation.persistedMessages(inContext: self.context)
				self.sentMessageObjectIds.append(contentsOf: mmos.map({$0.objectID}))
				let messagesToSend = mmos.compactMap({MOMessage.init(messageManagedObject: $0)})
				if !messagesToSend.isEmpty {
					MMLogDebug("[Message posting] posting pending MO messages...")
					self.sendMessages(Array(messagesToSend), internalId: internalId)
				} else {
					MMLogDebug("[Message posting] nothing to send...")
					self.finish()
				}
			}
		}
	}
	
	func sendMessages(_ msgs: [MOMessage], internalId: String) {
		self.postWillSendNotification(messagesToSend: msgs)
		self.mmContext.remoteApiProvider.sendMessages(internalUserId: internalId, messages: msgs) { result in
			self.operationResult = result
			self.handleResult(result: result, originalMessagesToSend: msgs) {
				self.finishWithError(result.error)
			}
		}
	}
	
	static func findNewMOMessages(among messages: Set<MOMessage>, inContext context: NSManagedObjectContext) -> [MOMessage] {
		return Set(messages.map(MMMessageMeta.init)).subtracting(MessagePostingOperation.persistedMessageMetas(inContext: context)).compactMap { meta in
				return messages.first() { msg -> Bool in
					return msg.messageId == meta.messageId
				}
			}
	}
	
	static func persistedMessages(inContext ctx: NSManagedObjectContext) -> [MessageManagedObject] {
		var ret = [MessageManagedObject]()
		ctx.performAndWait {
			if let persistedMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageTypeValue == \(MMMessageType.MO.rawValue)"), context: ctx) {
				ret = persistedMessages
			}
		}
		return ret
	}
	
	static func persistedMoMessages(inContext ctx: NSManagedObjectContext) -> [MOMessage] {
		return MessagePostingOperation.persistedMessages(inContext: ctx).compactMap(MOMessage.init)
	}
	
	static func persistedMessageMetas(inContext ctx: NSManagedObjectContext) -> [MMMessageMeta] {
		return MessagePostingOperation.persistedMessages(inContext: ctx).map(MMMessageMeta.init)
	}
	
	private func populateMessageStorageIfNeeded(with messages: [MOMessage], completion: @escaping () -> Void) {
		guard isUserInitiated else {
			completion()
			return
		}
		let storages = mmContext.messageStorages.values
		storages.forEachAsync({ (storage, finishBlock) in
			storage.insert(outgoing: Array(messages), completion: finishBlock)
		}, completion: completion)
	}
	
	private func updateMessageStorageIfNeeded(with messages: [MOMessage], completion: @escaping () -> Void) {
		guard !messages.isEmpty, isUserInitiated else {
			completion()
			return
		}
		let storages = mmContext.messageStorages.values
		storages.forEachAsync({ (storage, finishBlock) in
			storage.batchSentStatusUpdate(messages: messages, completion: finishBlock)
		}, completion: completion)
	}
	
	private func updateMessageStorageOnFailureIfNeeded(with messageIds: [String], completion: @escaping () -> Void) {
		guard !messageIds.isEmpty, isUserInitiated else {
			completion()
			return
		}
		let storages = mmContext.messageStorages.values
		storages.forEachAsync({ (storage, finishBlock) in
			storage.batchFailedSentStatusUpdate(messageIds: messageIds, completion: finishBlock)
		}, completion: completion)
	}
	
	private func postWillSendNotification(messagesToSend: Array<MOMessage>) {
		NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationMessagesWillSend, userInfo: [MMNotificationKeyMessageSendingMOMessages: messagesToSend])
	}
	
	private func postDidSendNotification(messages: [MOMessage]) {
		NotificationCenter.mm_postNotificationFromMainThread(name: MMNotificationMessagesDidSend, userInfo: [MMNotificationKeyMessageSendingMOMessages: messages])
	}
	
	private func handleResult(result: MOMessageSendingResult, originalMessagesToSend: Array<MOMessage>, completion: @escaping () -> Void) {
		context.performAndWait {
			switch result {
			case .Success(let response):
				
				// we sent messages, we delete them now
				MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "SELF IN %@", self.sentMessageObjectIds), context: self.context)?.forEach() { m in
					self.context.delete(m)
				}
				
				guard !self.isCancelled else {
					completion()
					return
				}
				
				self.context.MM_saveToPersistentStoreAndWait()
				self.updateMessageStorageIfNeeded(with: response.messages) {
					self.postDidSendNotification(messages: response.messages)
					completion()
				}
				MMLogDebug("[Message posting] successfuly finished")
			case .Failure(let error):
				MMLogError("[Message posting] request failed with error: \(error.orNil)")
				self.updateMessageStorageOnFailureIfNeeded(with: originalMessagesToSend.map { $0.messageId } , completion: {
					completion()
				})
			case .Cancel:
				MMLogError("[Message posting] cancelled")
				completion()
			}
		}
	}
	
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Message posting] finished with errors: \(errors)")
		let finishResult = errors.isEmpty ? operationResult : MOMessageSendingResult.Failure(errors.first)
		self.finishBlock?(finishResult)
	}
}
