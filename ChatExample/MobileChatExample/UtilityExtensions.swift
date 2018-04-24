//
//  UtilityExtensions.swift
//  MobileChatExample
//
//  Created by Andrey Kadochnikov on 10/11/2017.
//  Copyright © 2017 Infobip d.o.o. All rights reserved.
//

import Foundation
import UIKit
import MobileMessaging

extension UIAlertController {
	static func makeComposingAlert(sendActionBlock: @escaping (String) -> Void) -> UIAlertController {
		let alertController = UIAlertController(title: "New message", message: "Please enter new message", preferredStyle: UIAlertControllerStyle.alert)
		let sendAction = UIAlertAction(title: "Send", style: .default) { (_) in
			let messageTextTF = alertController.textFields![0] as UITextField
			if let messageText = messageTextTF.text {
				sendActionBlock(messageText)
			}
		}
		sendAction.isEnabled = false
		
		alertController.addTextField { (textField) in
			textField.placeholder = "Message text"
			textField.autocapitalizationType = .sentences
			NotificationCenter.default.addObserver(forName: NSNotification.Name.UITextFieldTextDidChange, object: textField, queue: OperationQueue.main) { (notification) in
				sendAction.isEnabled = textField.text != ""
			}
		}
		alertController.addAction(sendAction)
		alertController.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
		return alertController
	}
}

extension CGRect {
	var width: CGFloat {
		set {
			self.size.width = newValue
		}
		get {
			return self.size.width
		}
	}
	var height: CGFloat {
		set {
			self.size.height = newValue
		}
		get {
			return self.size.height
		}
	}
	var x: CGFloat {
		set {
			self.origin.x = newValue
		}
		get {
			return self.origin.x
		}
	}
	var y: CGFloat {
		set {
			self.origin.y = newValue
		}
		get {
			return self.origin.y
		}
	}
}

extension NSAttributedString {
	static func makeChatMessageText(with chatMessage: ChatMessage) -> NSAttributedString {
		let date = Date(timeIntervalSince1970: chatMessage.sendDateTime).toAgoTimeString()
		let st = NSMutableAttributedString()
		if !chatMessage.isYours {
			let nickname = chatMessage.author?.username
			if let nickname = nickname {
                st.append(NSAttributedString(string: nickname, attributes: [NSAttributedString.fontAttributeName: UIFont.systemFont(ofSize: 14), NSAttributedString.foregroundColorAttributeName: UIColor.gray]))
                st.append(NSAttributedString(string: "\n"))
			}
		}
        st.append(NSAttributedString(string: chatMessage.body, attributes: [NSAttributedString.fontAttributeName: UIFont.systemFont(ofSize: 17)]))
		st.append(NSAttributedString(string: "\n"))
        st.append(NSAttributedString(string: date, attributes: [NSAttributedString.fontAttributeName: UIFont.systemFont(ofSize: 10), NSAttributedString.foregroundColorAttributeName: UIColor.gray]))
		return st
	}
    
    #if swift(>=4.0)
    static let foregroundColorAttributeName =  NSAttributedStringKey.foregroundColor
    static let fontAttributeName =  NSAttributedStringKey.font
    static let paragraphStyleAttributeName =  NSAttributedStringKey.paragraphStyle
    #else
    static let foregroundColorAttributeName = NSForegroundColorAttributeName
    static let fontAttributeName = NSFontAttributeName
    static let paragraphStyleAttributeName =  NSParagraphStyleAttributeName
    #endif
}

extension Date {
	func toAgoTimeString() -> String {
		let formatter = DateFormatter()
		let diffSec = Int(Date().timeIntervalSinceReferenceDate - self.timeIntervalSinceReferenceDate)
		let day: Int = 60*60*24
		switch diffSec {
		case 0...day:
			formatter.timeStyle = DateFormatter.Style.short
			formatter.dateStyle = DateFormatter.Style.none
			return formatter.string(from: self)
		case day...day*7:
			let dateComponentsString = "hh:mm EE"
			if let format = DateFormatter.dateFormat(fromTemplate: dateComponentsString, options: 0, locale: Locale.current) {
				formatter.dateFormat = format
				return formatter.string(from: self)
			}
		default:
			formatter.dateStyle = DateFormatter.Style.short
			formatter.timeStyle = DateFormatter.Style.short
			return formatter.string(from: self)
		}
		return ""
	}
}
