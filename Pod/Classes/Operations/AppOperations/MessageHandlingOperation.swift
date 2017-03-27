//
//  MessageHandlingOperation.swift
//
//  Created by Andrey K. on 20/04/16.
//
//

import UIKit
import CoreData

func == (lhs: MMMessageMeta, rhs: MMMessageMeta) -> Bool {
	return lhs.hashValue == rhs.hashValue
}

struct MMMessageMeta : MMMessageMetadata {
	let isSilent: Bool
	let messageId: String
	
	var hashValue: Int {
		return messageId.hash
	}
	
	init(message: MessageManagedObject) {
		self.messageId = message.messageId
		self.isSilent = message.isSilent
	}
	
	init(message: MTMessage) {
		self.messageId = message.messageId
		self.isSilent = message.isSilent
	}
}

final class MessageHandlingOperation: Operation {
	let context: NSManagedObjectContext
	let finishBlock: ((NSError?) -> Void)?
	let messagesToHandle: [MTMessage]
	let messageHandler: MessageHandling
	let applicationState: UIApplicationState
	let mmContext: MobileMessaging
	
	init(messagesToHandle: [MTMessage], context: NSManagedObjectContext, messageHandler: MessageHandling, applicationState: UIApplicationState, mmContext: MobileMessaging, finishBlock: ((NSError?) -> Void)? = nil) {
		self.messagesToHandle = messagesToHandle //can be either native APNS or custom Server layout
		self.context = context
		self.finishBlock = finishBlock
		self.messageHandler = messageHandler
		self.applicationState = applicationState
		self.mmContext = mmContext
		super.init()
		
		self.userInitiated = true
	}
	
	override func execute() {
		MMLogDebug("[Message handling] Starting message handling operation...")
		context.reset()
		guard !newMessages.isEmpty else
		{
			MMLogDebug("[Message handling] There is no new messages to handle.")
			handleExistentMessageTappedIdNeeded()
			finish()
			return
		}
		
		MMLogDebug("[Message handling] There are \(newMessages.count) new messages to handle.")
		
		context.performAndWait {
			self.newMessages.forEach { newMessage in
				let newDBMessage = MessageManagedObject.MM_createEntityInContext(context: self.context)
				newDBMessage.messageId = newMessage.messageId
				newDBMessage.creationDate = newMessage.createdDate
				newDBMessage.isSilent = newMessage.isSilent
				newDBMessage.reportSent = newMessage.isDeliveryReportSent
				newDBMessage.messageType = .Default
				
				// Add new regions for geofencing
				if let geoMessage = newMessage as? MMGeoMessage, let geoService = MobileMessaging.geofencingService, geoService.isRunning {
					newDBMessage.payload = newMessage.originalPayload
					newDBMessage.messageType = .Geo
					newDBMessage.campaignState = .Active
					newDBMessage.campaignId = geoMessage.campaignId
					geoService.add(message: geoMessage)
				}
			}
			self.context.MM_saveToPersistentStoreAndWait()
		}
		
		let notGeoMessages: [MTMessage] = newMessages.filter { !($0 is MMGeoMessage) }
		notifyAboutNewMessages(notGeoMessages)
		populateMessageStorageWithNewMessages(notGeoMessages)
		finish()
	}
	
	private func populateMessageStorageWithNewMessages(_ messages: [MTMessage]) {
		guard !messages.isEmpty else { return }
		MMLogDebug("[Message handling] inserting messages in message storage: \(messages)")
		mmContext.messageStorageAdapter?.insert(incoming: messages)
	}

	
	private func notifyAboutNewMessages(_ messages: [MTMessage]) {
		guard !messages.isEmpty else { return }
		MMQueue.Main.queue.executeAsync {
			self.handleNewMessageTappedIfNeeded(messages)
			messages.forEach { message in
				MMLogDebug("[Message handling] calling message handling didReceiveNewMessage")
				self.messageHandler.didReceiveNewMessage(message: message)
				self.postNotificationForObservers(with: message)
			}
		}
	}
	
	private func postNotificationForObservers(with message: MTMessage) {
		NotificationCenter.default.post(name: NSNotification.Name(rawValue: MMNotificationMessageReceived), object: self, userInfo: [MMNotificationKeyMessage: message])
	}
	
//MARK: - Notification tap handling
	private var isNotificationTapped: Bool {
		return applicationState == .inactive && messagesToHandle.count == 1
	}
	
	private func handleExistentMessageTappedIdNeeded() {
		guard let existentMessage = intersectingMessages.first else { return }
		handleNotificationTappedIfNeeded(with: existentMessage)
	}
	
	private func handleNewMessageTappedIfNeeded(_ messages: [MTMessage]) {
		guard let newMessage = messages.first else { return }
		handleNotificationTappedIfNeeded(with: newMessage)
	}
	
	private func handleNotificationTappedIfNeeded(with message: MTMessage) {
		guard isNotificationTapped else { return }
		MMMessageHandler.handleNotificationTap(with: message)
	}
	
//MARK: - Lazy message collections
	private lazy var storedMessageMetasSet: Set<MMMessageMeta> = {
		var result: Set<MMMessageMeta> = Set()
		//TODO: optimization needed, it may be too many of db messages
		self.context.performAndWait {
			if let storedMessages = MessageManagedObject.MM_findAllInContext(self.context) {
				result = Set(storedMessages.map(MMMessageMeta.init))
			}
		}
		return result
	}()
	
	private lazy var newMessages: Set<MTMessage> = {
		guard !self.messagesToHandle.isEmpty else { return Set<MTMessage>() }
		let messagesToHandleMetasSet = Set(self.messagesToHandle.map(MMMessageMeta.init))
		return Set(messagesToHandleMetasSet.subtracting(self.storedMessageMetasSet).flatMap{ return self.mtMessage(from: $0) })
	}()
	
	private lazy var intersectingMessages: [MTMessage] = {
		guard !self.messagesToHandle.isEmpty else { return [MTMessage]() }
		let messagesToHandleMetasSet = Set(self.messagesToHandle.map(MMMessageMeta.init))
		return messagesToHandleMetasSet.intersection(self.storedMessageMetasSet).flatMap{ return self.mtMessage(from: $0) }
	}()
	
//MARK: - Lazy message collections
	private func mtMessage(from meta: MMMessageMeta) -> MTMessage? {
		if let message = self.messagesToHandle.filter({ (msg: MTMessage) -> Bool in
			return msg.messageId == meta.messageId
		}).first {
			return message
		} else {
			return nil
		}
	}
	
//MARK: -
	override func finished(_ errors: [NSError]) {
		MMLogDebug("[Message handling] Message handling finished with errors: \(errors)")
		self.finishBlock?(errors.first)
	}
}
