//
//  CPBarButtonItem.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2017.
//

import Foundation

class CPBarButtonItem : UIBarButtonItem {
	var actionBlock: (CPBarButtonItem) -> Void
	init(actionBlock: @escaping (CPBarButtonItem) -> Void) {
		self.actionBlock = actionBlock
		
		super.init()
		style = .plain
		target = self
		action = #selector(CPBarButtonItem.performActionBlock)
	}
	
    @objc func performActionBlock() {
		self.actionBlock(self)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class CPButton: UIButton {
	var actionBlock: ((CPButton) -> Void)? {
		didSet {
			addTarget(self, action: #selector(CPButton.performActionBlock), for: .touchUpInside)
		}
	}
	
    @objc func performActionBlock() {
		self.actionBlock?(self)
	}
}
