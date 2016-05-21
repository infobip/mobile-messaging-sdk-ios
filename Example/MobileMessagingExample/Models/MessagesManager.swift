//
//  MessagesManager.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 20/05/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit
import MobileMessaging

let kMessageDidChangeSeenNotification = "kMessageDidChangeSeenNotification"
let kMessagesKey = "kMessagesKey"

class Message : NSObject, NSCoding {
	var text: String
	var messageId: String
	dynamic var delivered: Bool = false
	var seen : Bool = false {
		didSet {
			NSNotificationCenter.defaultCenter().postNotificationName(kMessageDidChangeSeenNotification, object: self, userInfo: nil)
		}
	}
	
	required init(text: String, messageId: String){
		self.text = text
		self.messageId = messageId
		super.init()
	}
	
	//MARK: NSCoding
	required init(coder aDecoder: NSCoder) {
		text = aDecoder.decodeObjectForKey("text") as! String
		messageId = aDecoder.decodeObjectForKey("messageId") as! String
		delivered = aDecoder.decodeBoolForKey("delivered")
		seen = aDecoder.decodeBoolForKey("seen")
	}
	
	func encodeWithCoder(aCoder: NSCoder) {
		aCoder.encodeObject(text, forKey: "text")
		aCoder.encodeObject(messageId, forKey: "messageId")
		aCoder.encodeBool(delivered, forKey: "delivered")
		aCoder.encodeBool(seen, forKey: "seen")
	}
	
	//MARK: Util
	class func prepare(rawMessage: [NSObject : AnyObject]) -> Message? {
		guard let aps = rawMessage["aps"] as? [NSObject : AnyObject],
			let messageId = rawMessage["messageId"] as? String else {
				return nil
		}
		
		var text = String()
		if let alert = aps["alert"] as? String {
			text = alert
		} else if let alert = aps["alert"] as? [NSObject : AnyObject],
			let body = alert["body"] as? String {
			text = body
		} else {
			return nil
		}
		
		return Message(text: text, messageId: messageId)
	}
}

final class MessagesManager: NSObject, UITableViewDataSource {
	static let sharedInstance = MessagesManager()
	var newMessageBlock: ((Message) -> Void)?
	var messages = [Message]()

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	override init() {
		super.init()
		unarchiveMessages()
		startObservingNotifications()
	}
	
	func cleanMessages() {
		synced(self) {
			self.messages.removeAll()
			NSUserDefaults.standardUserDefaults().removeObjectForKey(kMessagesKey)
		}
	}
	
	//MARK: Private
	private func synced(lock: AnyObject, closure: () -> ()) {
		objc_sync_enter(lock)
		closure()
		objc_sync_exit(lock)
	}
	
	private func startObservingNotifications() {
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MessagesManager.appWillTerminate), name: UIApplicationWillTerminateNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MessagesManager.handleNewMessageReceivedNotification(_:)), name: MMEventNotifications.kMessageReceived, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MessagesManager.handleDeliveryReportSentNotification(_:)), name: MMEventNotifications.kDeliveryReportSent, object: nil)
	}
	
	private func archiveMessages() {
		synced(self) {
			let data: NSData = NSKeyedArchiver.archivedDataWithRootObject(self.messages)
			NSUserDefaults.standardUserDefaults().setObject(data, forKey: kMessagesKey)
		}
	}
	
	private func unarchiveMessages() {
		synced(self) {
			if let messagesData = NSUserDefaults.standardUserDefaults().objectForKey(kMessagesKey) as? NSData,
				let messages = NSKeyedUnarchiver.unarchiveObjectWithData(messagesData) as? [Message] {
				self.messages.appendContentsOf(messages)
			}
		}
	}
	
	//MARK: Handle notifications
	func appWillTerminate() {
		archiveMessages()
	}
	
	func handleNewMessageReceivedNotification(notification: NSNotification) {
		guard let userInfo = notification.userInfo,
			let messageUserInfo = userInfo[MMEventNotifications.kMessageUserInfoKey] as? [NSObject : AnyObject],
			let message = Message.prepare(messageUserInfo) else {
				return
		}
		
		synced(self) {
			self.messages.insert(message, atIndex: 0)
		}
		
		newMessageBlock?(message)
	}
	
	func handleDeliveryReportSentNotification(notification: NSNotification) {
		guard let userInfo = notification.userInfo,
			let messageUserInfo = userInfo[MMEventNotifications.kMessageIDsUserInfoKey] as? [String] else {
				return
		}
		
		for message in messages {
			if messageUserInfo.contains(message.messageId) {
				message.delivered = true
			}
		}
	}

	//MARK: UITableViewDataSource
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return messages.count
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		if let cell = tableView.dequeueReusableCellWithIdentifier(kMessageCellId, forIndexPath: indexPath) as? MessageCell {
			cell.message = messages[indexPath.row]
			return cell
		}
		fatalError()
	}
}