//
//  ChatService.swift
//
//  Created by okoroleva on 06.10.17.
//

import Foundation
import CoreData

@objc public protocol MobileChatProtocol {
	/// Sends message with a specified text to a particular chat id.
	/// - Parameters:
	///   - chatId: id of destination chat
	///   - text: body of the message
	///   - completion: a block to be executed when sending is finished
	func send(chatId: String?, text: String, completion: ((ChatMessage?, NSError?) -> Void)?)
	
	/// Sends message with a specified text to a particular chat id.
	/// - Parameters:
	///   - chatId: id of destination chat
	///   - text: body of the message
	///   - customPayload: additional data to send along with the chat message
	///   - completion: a block to be executed when sending is finished. Contains a sent message object and an error
	func send(chatId: String?, text: String, customPayload: [String: CustomPayloadSupportedTypes], completion: ((ChatMessage?, NSError?) -> Void)?)
	
	/// Sets user info for curren chat user.
	/// - Parameters:
	///   - info: object representing chat user data
	///   - completion: a block to be executed when operation is finished. Contains an error object
	func setUserInfo(info: ChatParticipant, completion: ((NSError?) -> Void)?)
	
	/// Returns chat users profile cached locally.
	/// - Returns: `ChatParticipant` object representing chat user data
	func getUserInfo() -> ChatParticipant?
	
	/// Returns chat users profile from the server.
	/// - Parameters:
	///  - completion: a block to be executed when operation is finished. Contains the fetched chat user data
	func fetchUserInfo(completion: ((ChatParticipant?) -> Void)?)

	/// Returns the default chat messsage storage if used. For more information see `MMDefaultMessageStorage` class description.
	var defaultChatStorage: MMDefaultChatStorage? { get }
	
	/// Marks all messages as seen
	func markAllMessagesSeen(completion: (() -> Void)?)
	
	/// Marks specific messages as seen
	func markMessagesSeen(messageIds: [String], completion: (() -> Void)?)
	
	/// A wrapper around NSFetchedResultsController set up to manage the results of a Core Data fetch request applied to chat message storage. Only available for default chat message storage (returns `nil` otherwise).
	var chatMessagesController: ChatMessagesController? {get}
}

public class MobileChat: NSObject, MobileMessagingService {
	func logout(_ mmContext: MobileMessaging, completion: @escaping ((NSError?) -> Void)) {
		// do nothing?
	}
	
	let storage: MessageStorage
	let mmContext: MobileMessaging
	
	var uniqueIdentifier: String {
		return "com.mobile-messaging.subservice.ChatService"
	}
	
	var systemData: [String: AnyHashable]? {
		return ["chat": true]
	}
	
	var isRunning: Bool = true
	
	func start(_ completion: ((Bool) -> Void)?) {
		isRunning = true
	}
	
	func stop(_ completion: ((Bool) -> Void)?) {
		isRunning = false
	}

	func mobileMessagingDidStop(_ mmContext: MobileMessaging) {
		stop(nil)
		MobileChat.sharedInstance = nil
	}

	func syncWithServer(_ completion: ((NSError?) -> Void)?) {
		
	}
	
	static var sharedInstance: MobileChat?
	
	init(mmContext: MobileMessaging, storage: MessageStorage) {
		self.mmContext = mmContext
		self.storage = storage
		super.init()
		self.mmContext.chatStorage = storage
		registerSelfAsSubservice(of: mmContext)
	}
	
    public let settings: ChatSettings = ChatSettings.sharedInstance
}

extension MobileChat: MobileChatProtocol {
	
	public func markMessagesSeen(messageIds: [String], completion: (() -> Void)?) {
		mmContext.setSeen(messageIds)
		completion?()
	}
	
	public func markAllMessagesSeen(completion: (() -> Void)? = nil) {
		guard let storage = (mmContext.chatStorage as? MessageStorageFinders) else {
			completion?()
			return
		}
		storage.findAllMessageIds { (mids) in
			self.markMessagesSeen(messageIds: mids, completion: completion)
		}
	}
	
	public var chatMessagesController: ChatMessagesController? {
		guard let frc = defaultChatStorage?.fetchedResultController else {
			return nil
		}
		return ChatMessagesController(frc: frc)
	}
	
	public var defaultChatStorage: MMDefaultChatStorage? {
		return mmContext.chatStorage as? MMDefaultChatStorage
	}
	
	public func send(chatId: String? = nil, text: String, completion: ((ChatMessage?, NSError?) -> Void)? = nil) {
        doSend(chatId: chatId, text: text, customPayload: nil, completion: completion)
	}
	
	public func send(chatId: String? = nil, text: String, customPayload: [String : CustomPayloadSupportedTypes], completion: ((ChatMessage?, NSError?) -> Void)? = nil) {
		doSend(chatId: chatId, text: text, customPayload: customPayload, completion: completion)
	}
	
	public func setUserInfo(info: ChatParticipant, completion: ((NSError?) -> Void)?) {
		MMLogDebug("[Mobile chat] setting chat user info...")
		mmContext.currentUser.applyChatParticipantAttributes(participantInfo: info)
		mmContext.currentUser.save(completion)
	}
	
	public func getUserInfo() -> ChatParticipant? {
		MMLogDebug("[Mobile chat] getting chat user info...")
		return ChatParticipant.current(with: self.mmContext.currentUser)
	}
	
	public func fetchUserInfo(completion: ((ChatParticipant?) -> Void)?) {
		MMLogDebug("[Mobile chat] fetching chat user info...")
		mmContext.currentUser.fetchFromServer { (error) in
			MMLogDebug("[Mobile chat] fetching chat user info finished. Error: \(error.debugDescription)")
			completion?(ChatParticipant.current(with: self.mmContext.currentUser))
		}
	}
	
	public var messageStorage: MessageStorage {
		return storage
	}
    
    private func doSend(chatId: String?, text: String, customPayload: [String : CustomPayloadSupportedTypes]?, completion: ((ChatMessage?, NSError?) -> Void)?) {
        MMLogDebug("[Mobile chat] sending message...")
        guard let author = ChatParticipant.current, let chatServiceMo = ChatMessage(chatId: chatId, text: text, customPayload: customPayload, composedData: MobileMessaging.date.now, author: author).mo else {
            MMLogDebug("[Mobile chat] sending message interrupted: current user unavailable")
            completion?(nil, nil)
            return
        }
        
        mmContext.sendMessagesUserInitiated([chatServiceMo]) { (mss, error) in
            if let moresponse = mss?.first {
                let chatMessage = ChatMessage(moMessage: moresponse)
				MMLogDebug("[Mobile chat] message sending finished. Message: \(String(describing: chatMessage?.id)). Error: \(error.debugDescription)")
                completion?(chatMessage, error)
            } else {
                MMLogDebug("[Mobile chat] message sending finished. No message in response! Error: \(error.debugDescription)")
                completion?(nil, error)
            }
        }
    }
}
