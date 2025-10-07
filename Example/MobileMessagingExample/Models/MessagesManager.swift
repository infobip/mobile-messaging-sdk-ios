// 
//  Example/MobileMessagingExample/Models/MessagesManager.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import UIKit
import MobileMessaging

let kMessageSeenAttribute = "seen"
let kMessageDeliveryReportSentAttribute = "deliveryReportSent"
let kMessagesKey = "kMessagesKey"

class Message: NSObject, NSSecureCoding {
    static var supportsSecureCoding = true
    
	typealias APNSPayload = [String: Any]
	var text: String
	var messageId: String
    @objc dynamic var deliveryReportSent: Bool = false
    @objc dynamic var seen : Bool = false
	
	required init(text: String, messageId: String){
		self.text = text
		self.messageId = messageId
		super.init()
	}
	
	//MARK: NSCoding
	required init(coder aDecoder: NSCoder) {
        text = aDecoder.decodeObject(of: NSString.self, forKey: "text")! as String
        messageId = aDecoder.decodeObject(of: NSString.self, forKey: "messageId")! as String
		deliveryReportSent = aDecoder.decodeBool(forKey: kMessageDeliveryReportSentAttribute)
		seen = aDecoder.decodeBool(forKey: kMessageSeenAttribute)
	}
	
	func encode(with aCoder: NSCoder) {
		aCoder.encode(text, forKey: "text")
		aCoder.encode(messageId, forKey: "messageId")
		aCoder.encode(deliveryReportSent, forKey: kMessageDeliveryReportSentAttribute)
		aCoder.encode(seen, forKey: kMessageSeenAttribute)
	}
	
	//MARK: Util
	class func make(from mtMessage: MM_MTMessage) -> Message? {
		guard let text = mtMessage.text else {
			return nil
		}
		return Message(text: text, messageId: mtMessage.messageId)
	}
}

final class MessagesManager: NSObject, UITableViewDataSource {
	static let sharedInstance = MessagesManager()
	var newMessageBlock: ((Message) -> Void)?
	var messages = [Message]()

	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	override init() {
		super.init()
		unarchiveMessages()
		startObservingNotifications()
	}
	
	func cleanMessages() {
		synced(self) {
			self.messages.removeAll()
			UserDefaults.standard.removeObject(forKey: kMessagesKey)
		}
	}
	
	//MARK: Private
	fileprivate func synced(_ lock: AnyObject, closure: () -> Void) {
		objc_sync_enter(lock)
		closure()
		objc_sync_exit(lock)
	}
	
	fileprivate func startObservingNotifications() {
		NotificationCenter.default.addObserver(self,
		                                       selector: #selector(MessagesManager.appWillTerminate),
		                                       name: UIApplication.willTerminateNotification,
		                                       object: nil)
		
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(MessagesManager.handleNewMessageReceivedNotification(_:)),
                                               name: NSNotification.Name(rawValue: MMNotificationMessageReceived),
                                               object: nil)
        
		NotificationCenter.default.addObserver(self,
		                                       selector: #selector(MessagesManager.handleDeliveryReportSentNotification(_:)),
		                                       name: NSNotification.Name(rawValue: MMNotificationDeliveryReportSent),
		                                       object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(MessagesManager.handleTapNotification),
                                               name: NSNotification.Name(rawValue: MMNotificationMessageTapped),
                                               object: nil)
	}
	
	fileprivate func archiveMessages() {
		synced(self) {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: self.messages, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: kMessagesKey)
                UserDefaults.standard.synchronize()
            }
		}
    }
    
    fileprivate func unarchiveMessages() {
        synced(self) {
            if let messagesData = UserDefaults.standard.object(forKey: kMessagesKey) as? Data {
                do {
                    let messages = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, Message.self], from: messagesData)
                    if let m = messages as? [Message] {
                        self.messages.append(contentsOf: m)
                    }
                } catch {
                    MMLogError("Unable to unarchive messagesData")
                }
            }
        }
    }
    
    //MARK: Handle notifications
    @objc func appWillTerminate() {
        archiveMessages()
	}
	
    @objc func handleNewMessageReceivedNotification(_ notification: Notification) {
		guard let userInfo = notification.userInfo,
			let mtmessage = userInfo[MMNotificationKeyMessage] as? MM_MTMessage,
			let message = Message.make(from: mtmessage) else
		{
			return
		}
		
		synced(self) {
			self.messages.insert(message, at: 0)
		}
        		
		newMessageBlock?(message)
	}
	
    @objc func handleDeliveryReportSentNotification(_ notification: Notification) {
		guard let userInfo = notification.userInfo,
			let messageUserInfo = userInfo[MMNotificationKeyDLRMessageIDs] as? [String] else {
				return
		}
		
		for message in messages {
			if messageUserInfo.contains(message.messageId) {
				message.deliveryReportSent = true
			}
		}
	}
    
    @objc func handleTapNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let message = userInfo[MMNotificationKeyMessage] as? MM_MTMessage
            else {
				return
		}
		LinksHandler.handleLinks(fromMessage: message)
	}

	//MARK: UITableViewDataSource
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return messages.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if let cell = tableView.dequeueReusableCell(withIdentifier: kMessageCellId, for: indexPath) as? MessageCell {
			cell.message = messages[indexPath.row]
			return cell
		}
		fatalError()
	}
}
