//
//  CPChatNavigationVC.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2017.
//

import Foundation

/// Default chat view implementation, extends UINavigationController with a CPChatViewController put as a root view controller.
open class CPChatNavigationVC: UINavigationController {
	var isModal: Bool = false

	public required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}

	override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
	
	public override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if isBeingPresented {
			isModal = true
		} else if isMovingToParent {
			isModal = false
		}
	}

	static func makeWebViewChatNavigationViewController() -> CPChatNavigationVC {
		return CPChatNavigationVC.init(rootViewController : CPChatViewController(type: .dismiss))
	}
}
