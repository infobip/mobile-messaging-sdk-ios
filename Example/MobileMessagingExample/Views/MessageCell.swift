// 
//  Example/MobileMessagingExample/Views/MessageCell.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import UIKit

class MessageCell: UITableViewCell {
	
	deinit {
		resetMessageObserving()
	}
	
	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		textLabel?.numberOfLines = 5
		accessoryType = .disclosureIndicator
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
			message?.addObserver(self, forKeyPath: kMessageSeenAttribute, options: .new, context: nil)
		}
	}
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if keyPath == kMessageSeenAttribute {
			refreshSeenStatus()
		} else {
			super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
		}
	}
	
	fileprivate func resetMessageObserving() {
		message?.removeObserver(self, forKeyPath: kMessageSeenAttribute)
	}
	
	fileprivate func refreshSeenStatus() {
		guard let message = message else {
			return
		}
		textLabel?.font = message.seen ? UIFont.systemFont(ofSize: 15.0) : UIFont.boldSystemFont(ofSize: 15.0)
	}
}
