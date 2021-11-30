//
//  MessagePostingOperation.swift
//
//  Created by Andrey K. on 19/07/16.
//
//

import UIKit
import CoreData

class MessagePostingOperation: MMOperation {
	
	let context: NSManagedObjectContext
	let finishBlock: ((MOMessageSendingResult) -> Void)?
	let messages: Set<MM_MOMessage>?
	let mmContext: MobileMessaging
	var sentMessageObjectIds = [NSManagedObjectID]()
	var operationResult = MOMessageSendingResult.Cancel
	
    init(userInitiated: Bool, messages: [MM_MOMessage]?, isUserInitiated: Bool, context: NSManagedObjectContext, mmContext: MobileMessaging, finishBlock: ((MOMessageSendingResult) -> Void)? = nil) {
		self.context = context
		self.finishBlock = finishBlock
		if let messages = messages, !messages.isEmpty {
			self.messages = Set(messages)
		} else {
			self.messages = nil
		}
		self.mmContext = mmContext
		super.init(isUserInitiated: userInitiated)
		self.addCondition(HealthyRegistrationCondition(mmContext: mmContext))
	}
	
	override func execute() {
		logDebug("started...")
		guard let pushRegistrationId = mmContext.currentInstallation().pushRegistrationId else {
			logWarn("No registration. Finishing...")
			finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
			return
		}

		// if there were explicit messages to send
		if let messages = self.messages {
			var messagesToSend: [MM_MOMessage] = []

			context.performAndWait {
                context.reset()
				// new messages sending
				messagesToSend = MessagePostingOperation.findNewMOMessages(among: messages, inContext: self.context)
				
				// if not user-initiated we must guarantee retries, thus persist the MOs
				if !self.userInitiated {
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
			}

			logDebug("posting new MO messages...")
			self.populateMessageStorageIfNeeded(with: messagesToSend) {
				self.sendMessages(Array(messagesToSend), pushRegistrationId: pushRegistrationId)
			}
		} else {
			var messagesToSend: [MM_MOMessage] = []
			context.performAndWait {
                context.reset()
				// let's send persisted messages (retries)
				let mmos = MessagePostingOperation.persistedMessages(inContext: self.context)
				self.sentMessageObjectIds.append(contentsOf: mmos.map({$0.objectID}))
				messagesToSend = mmos.compactMap({MM_MOMessage.init(messageManagedObject: $0)})
			}
			if !messagesToSend.isEmpty {
				logDebug("posting pending MO messages...")
				self.sendMessages(Array(messagesToSend), pushRegistrationId: pushRegistrationId)
			} else {
				logDebug("nothing to send...")
				self.finish()
			}
		}

	}
	
	func sendMessages(_ msgs: [MM_MOMessage], pushRegistrationId: String) {
		UserEventsManager.postWillSendMessageEvent(msgs)
		let body = MOSendingMapper.requestBody(pushRegistrationId: pushRegistrationId, messages: msgs)
        self.mmContext.remoteApiProvider.sendMessages(applicationCode: self.mmContext.applicationCode, pushRegistrationId: pushRegistrationId, body: body, queue: underlyingQueue) { result in
			self.operationResult = result
			self.handleResult(result: result, originalMessagesToSend: msgs) {
				self.finishWithError(result.error)
			}
		}
	}
	
	static func findNewMOMessages(among messages: Set<MM_MOMessage>, inContext context: NSManagedObjectContext) -> [MM_MOMessage] {
		return Set(messages.map(MMMessageMeta.init)).subtracting(MessagePostingOperation.persistedMessageMetas(inContext: context)).compactMap { meta in
			return messages.first() { msg -> Bool in
				return msg.messageId == meta.messageId
			}
		}
	}
	
	static func persistedMessages(inContext ctx: NSManagedObjectContext) -> [MessageManagedObject] {
		var ret = [MessageManagedObject]()
		ctx.performAndWait {
			ret = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageTypeValue == \(MMMessageType.MO.rawValue)"), context: ctx) ?? ret
		}
		return ret
	}
	
	static func persistedMoMessages(inContext ctx: NSManagedObjectContext) -> [MM_MOMessage] {
		return MessagePostingOperation.persistedMessages(inContext: ctx).compactMap(MM_MOMessage.init)
	}
	
	static func persistedMessageMetas(inContext ctx: NSManagedObjectContext) -> [MMMessageMeta] {
		return MessagePostingOperation.persistedMessages(inContext: ctx).map(MMMessageMeta.init)
	}
	
	private func populateMessageStorageIfNeeded(with messages: [MM_MOMessage], completion: @escaping () -> Void) {
		guard userInitiated else {
			completion()
			return
		}
		let storages = mmContext.messageStorages.values
		storages.forEachAsync({ (storage, finishBlock) in
			storage.insert(outgoing: Array(messages), completion: finishBlock)
		}, completion: completion)
	}
	
	private func updateMessageStorageIfNeeded(with messages: [MM_MOMessage], completion: @escaping () -> Void) {
		guard !messages.isEmpty, userInitiated else {
			completion()
			return
		}
		let storages = mmContext.messageStorages.values
		storages.forEachAsync({ (storage, finishBlock) in
			storage.batchSentStatusUpdate(messages: messages, completion: finishBlock)
		}, completion: completion)
	}
	
	private func updateMessageStorageOnFailureIfNeeded(with messageIds: [String], completion: @escaping () -> Void) {
		guard !messageIds.isEmpty, userInitiated else {
			completion()
			return
		}
		let storages = mmContext.messageStorages.values
		storages.forEachAsync({ (storage, finishBlock) in
			storage.batchFailedSentStatusUpdate(messageIds: messageIds, completion: finishBlock)
		}, completion: completion)
	}
	
	private func handleResult(result: MOMessageSendingResult, originalMessagesToSend: Array<MM_MOMessage>, completion: @escaping () -> Void) {
		switch result {
		case .Success(let response):
			context.performAndWait {
				// we sent messages, we delete them now
				MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "SELF IN %@", self.sentMessageObjectIds), context: self.context)?.forEach() { m in
					self.context.delete(m)
				}
				self.context.MM_saveToPersistentStoreAndWait()
			}

			self.updateMessageStorageIfNeeded(with: response.messages) {
				UserEventsManager.postMessageSentEvent(response.messages)
				completion()
			}

			logDebug("successfuly finished")
		case .Failure(let error):
			logError("request failed with error: \(error.orNil)")
			self.updateMessageStorageOnFailureIfNeeded(with: originalMessagesToSend.map { $0.messageId } , completion: {
				completion()
			})
		case .Cancel:
			logWarn("cancelled")
			completion()
		}
	}
	
	override func finished(_ errors: [NSError]) {
        assert(userInitiated == Thread.isMainThread)
		logDebug("finished with errors: \(errors)")
		let finishResult = errors.isEmpty ? operationResult : MOMessageSendingResult.Failure(errors.first)
		self.finishBlock?(finishResult)
	}
}
