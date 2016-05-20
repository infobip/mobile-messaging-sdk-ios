//
//  MessageCell.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 20/05/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit

class MessageCell: UITableViewCell {
	
	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		textLabel?.numberOfLines = 5
		accessoryType = .DisclosureIndicator
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	var message: Message? {
		didSet {
			if let message = message {
				textLabel?.text = message.text
				refreshSeenStatus()
				NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(MessageCell.handleMessageDidChangeSeenNotification(_:)), name: kMessageDidChangeSeenNotification, object: message)
			}
		}
	}
	
	func handleMessageDidChangeSeenNotification(n: NSNotification) {
		refreshSeenStatus()
	}
	
	func refreshSeenStatus() {
		guard let message = message else {
			return
		}
		textLabel?.font = message.seen ? UIFont.systemFontOfSize(15.0) : UIFont.boldSystemFontOfSize(15.0)
	}
}