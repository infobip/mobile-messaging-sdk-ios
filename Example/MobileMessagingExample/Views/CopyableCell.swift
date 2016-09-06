//
//  CopyableLable.swift
//  MobileMessaging
//
//  Created by okoroleva on 06.04.16.
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
        isUserInteractionEnabled = true
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(CopyableCell.showMenu(_:))))
    }
    
    func showMenu(_ sender: Any?) {
		guard textLabel?.text != nil else {
			return
		}
		becomeFirstResponder()
		let menu = UIMenuController.shared
		if !menu.isMenuVisible {
			menu.setTargetRect(self.bounds, in: self)
			menu.setMenuVisible(true, animated: true)
		}
    }
	
	override func copy(_ sender: Any?) {
		guard let text = textLabel?.text else {
			return
		}
		UIPasteboard.general.string = text
		UIMenuController.shared.setMenuVisible(false, animated: true)
	}
	
	override var canBecomeFirstResponder: Bool {
		return true
	}
	    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) {
            return true
        }
        return false
    }
}
