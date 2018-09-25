//
//  CPChatNavigationVC.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2017.
//

import Foundation

/// Default chat view implementation, extends UINavigationController with a CPChatVC put as a root view controller.
public class CPChatNavigationVC: UINavigationController, ChatSettingsApplicable {
    
    /// Default chat view implementation, extends UIViewController.
	public let chatViewController: CPChatVC = CPChatVC()
	
	var isModal: Bool = false
	public override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if isBeingPresented {
			isModal = true
		} else if isMovingToParent {
			isModal = false
		}
	}
	
	override public func viewDidLoad() {
		super.viewDidLoad()
		registerToChatSettingsChanges()
	}
	
	func applySettings() {
        guard let settings = MobileMessaging.mobileChat?.settings else {
            return
        }
		navigationBar.barTintColor = settings.navBarColor
		navigationBar.tintColor = settings.navBarItemsTintColor
		navigationBar.isTranslucent = false
        navigationBar.titleTextAttributes = [NSAttributedString.foregroundColorAttributeName : settings.navBarTitleColor]
	}
	
	init() {
		super.init(rootViewController: chatViewController)
	}
	
	public required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.viewControllers = [chatViewController]
	}
}
