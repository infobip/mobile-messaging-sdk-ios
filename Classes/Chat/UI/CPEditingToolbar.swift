//
//  CPEditingToolbar.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2017.
//

import Foundation

class CPEditingToolbar: UIToolbar, ChatSettingsApplicable {
	
	var markAsReadBtn: CPBarButtonItem
	var deleteBtn: CPBarButtonItem
	
	init(markAsReadBtn: CPBarButtonItem, deleteBtn: CPBarButtonItem) {
		self.markAsReadBtn = markAsReadBtn
		self.deleteBtn = deleteBtn
		let space = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
		
		super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
		items = [markAsReadBtn, space, deleteBtn]
		autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
		barTintColor = UIColor.white
		registerToChatSettingsChanges()
	}
	
	func applySettings() {
        guard let settings = MobileMessaging.mobileChat?.settings else {
            return
        }
		tintColor = settings.tintColor
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
