//
//  CopyableLable.swift
//  MobileMessaging
//
//  Created by okoroleva on 06.04.16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import UIKit

class CopyableCell: UITableViewCell {
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        sharedInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInit()
    }
    
    func sharedInit() {
        userInteractionEnabled = true
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(CopyableCell.showMenu(_:))))
    }
    
    func showMenu(sender: AnyObject?) {
		guard textLabel?.text != nil else {
			return
		}
		becomeFirstResponder()
		let menu = UIMenuController.sharedMenuController()
		if !menu.menuVisible {
			menu.setTargetRect(self.bounds, inView: self)
			menu.setMenuVisible(true, animated: true)
		}
    }
    
    override func copy(sender: AnyObject?) {
		guard let text = textLabel?.text else {
			return
		}
		UIPasteboard.generalPasteboard().string = text
		UIMenuController.sharedMenuController().setMenuVisible(false, animated: true)
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override func canPerformAction(action: Selector, withSender sender: AnyObject?) -> Bool {
        if action == #selector(NSObject.copy(_:)) {
            return true
        }
        return false
    }
}