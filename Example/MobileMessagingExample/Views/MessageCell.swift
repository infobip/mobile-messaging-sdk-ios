//
//  MessageCell.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 20/05/16.
//

import UIKit

class MessageCell: UITableViewCell {
	
	deinit {
		resetMessageObserving()
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
		willSet {
			resetMessageObserving()
		}
		didSet {
			if let message = message {
				textLabel?.text = message.text
				refreshSeenStatus()
			}
			message?.addObserver(self, forKeyPath: kMessageSeenAttribute, options: .New, context: nil)
		}
	}
	
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if keyPath == kMessageSeenAttribute {
			refreshSeenStatus()
		} else {
			super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
		}
	}
	
	private func resetMessageObserving() {
		message?.removeObserver(self, forKeyPath: kMessageSeenAttribute)
	}
	
	private func refreshSeenStatus() {
		guard let message = message else {
			return
		}
		textLabel?.font = message.seen ? UIFont.systemFontOfSize(15.0) : UIFont.boldSystemFontOfSize(15.0)
	}
}