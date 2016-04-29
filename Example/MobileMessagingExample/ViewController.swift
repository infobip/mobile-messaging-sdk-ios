//
//  ViewController.swift
//  MobileMessaging
//
//  Created by Andrey K. on 03/29/2016.
//  Copyright (c) 2016 Andrey K.. All rights reserved.
//

import UIKit
import MobileMessaging
import Freddy

let kMessageCellId = "kMessageCellId"
let kMessageDetailsSegueId = "kMessageDetailsSegueId"
let kInformationSegueId = "kInformationSegueId"
let kSettingsSegueId = "kSettingsSegueId"
let kMessagesKey = "kMessagesKey"

class Message : NSObject, NSCoding {
    var text: String
    var messageId: String
    dynamic var delivered: Bool = false
    
    required init(text: String, messageId: String){
        self.text = text
        self.messageId = messageId
        super.init()
    }
    
    //MARK: NSCoding
    required init(coder aDecoder: NSCoder) {
        text = aDecoder.decodeObjectForKey("text") as! String
        messageId = aDecoder.decodeObjectForKey("messageId") as! String
        delivered = aDecoder.decodeObjectForKey("delivered") as! Bool
    }
    
    func encodeWithCoder(aCoder: NSCoder) {
        aCoder.encodeObject(text, forKey: "text")
        aCoder.encodeObject(messageId, forKey: "messageId")
        aCoder.encodeObject(delivered, forKey: "delivered")
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

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    
	@IBAction func trashInbox(sender: AnyObject) {
		messages.removeAll()
		NSUserDefaults.standardUserDefaults().removeObjectForKey(kMessagesKey)
		updateUI()
	}

	@IBAction func actionsButtonClicked(sender: UIBarButtonItem) {
		let informationAction = UIAlertAction(title: "Information", style: .Default) { (action) -> Void in
			self.performSegueWithIdentifier(kInformationSegueId, sender: sender)
		}
		
		let settingsAction = UIAlertAction(title: "Settings", style: .Default) { (action) -> Void in
			self.performSegueWithIdentifier(kSettingsSegueId , sender: sender)
		}
		
		let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
		
		let alert = UIAlertController(title: "Choose Action", message: nil, preferredStyle: .ActionSheet)
		alert.addAction(informationAction)
		alert.addAction(settingsAction)
		alert.addAction(cancelAction)

        presentViewController(alert, animated: true, completion: nil)
	}
	
    var messages:[Message] = [Message]()
    let cellFont = UIFont.systemFontOfSize(15.0)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startObservingNotifications()
        unarchiveMessages()
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: kMessageCellId)
		tableView.estimatedRowHeight = 44
		tableView.rowHeight = UITableViewAutomaticDimension;
	
        updateUI()
		
		
//		do {
//			let jstring = "{\"aps\":{\"alert\":{\"body\":\"test12 3123131 3131231231231  23123123fgf gfgfg bodytest123123131313123123123123123 123fgfgfgfgbody\",\"title\":\"testtitle\"},\"badge\":6,\"sound\":\"default\"},\"messageId\":\"123\"}"
//			let json = try JSON(jsonString: jstring)
//			let message = try MMMessage(json: json)
//			NSNotificationCenter.defaultCenter().postNotificationName(MMEventNotifications.kMessageReceived, object: self, userInfo: [MMEventNotifications.kMessageUserInfoKey: message.payload!])
//		} catch {
//		}
		
//		for i in 0..<10 {
//			let error = NSError(domain: "foo", code: 123, userInfo: [NSLocalizedDescriptionKey: "shit happens-\(i)"])
//			NSNotificationCenter.defaultCenter().postNotificationName(MMEventNotifications.kAPIError, object: self, userInfo: [MMEventNotifications.kAPIErrorUserInfoKey: error])
//		}
	}
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    
    //MARK: Handle MobileMessaging notifications
    func handleNewMessageReceivedNotification(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
            let messageUserInfo = userInfo[MMEventNotifications.kMessageUserInfoKey] as? [NSObject : AnyObject],
            let message = Message.prepare(messageUserInfo) else {
                return
        }
        
        saveMessage(message)
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
        let cell = tableView.dequeueReusableCellWithIdentifier(kMessageCellId, forIndexPath: indexPath)
        cell.textLabel?.numberOfLines = 5
        cell.textLabel?.font = cellFont
        cell.textLabel?.text = messages[indexPath.row].text
		cell.accessoryType = .DisclosureIndicator
        return cell
    }
	
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		performSegueWithIdentifier(kMessageDetailsSegueId, sender: indexPath)
	}
    
    //MARK: Segues
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == kMessageDetailsSegueId,
            let vc = segue.destinationViewController as? MessageDetailsViewController,
            let indexPath = sender as? NSIndexPath {
                vc.message = messages[indexPath.row]
        }
    }

    //MARK: Utils
    func updateUIWithInsertMessage() {
        tableView.insertRowsAtIndexPaths([NSIndexPath(forItem: 0, inSection: 0)], withRowAnimation: .Right)
        tableView.selectRowAtIndexPath(NSIndexPath(forItem: 0, inSection: 0), animated: true, scrollPosition: .Middle)
    }
    
    func updateUI() {
        tableView.reloadData()
    }
    
    func startObservingNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleNewMessageReceivedNotification:", name: MMEventNotifications.kMessageReceived, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleDeliveryReportSentNotification:", name: MMEventNotifications.kDeliveryReportSent, object: nil)
    }
    
    func saveMessage(message: Message) {
        messages.insert(message, atIndex: 0)
        let data: NSData = NSKeyedArchiver.archivedDataWithRootObject(messages)
        NSUserDefaults.standardUserDefaults().setObject(data, forKey: kMessagesKey)
        updateUIWithInsertMessage()
    }
    
    func unarchiveMessages() {
        if let messagesData = NSUserDefaults.standardUserDefaults().objectForKey(kMessagesKey) as? NSData,
            let messages = NSKeyedUnarchiver.unarchiveObjectWithData(messagesData) as? [Message] {
                self.messages.appendContentsOf(messages)
        }
    }
}

