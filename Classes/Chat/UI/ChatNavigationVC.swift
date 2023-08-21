//
//  CPChatNavigationVC.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2017.
//

import Foundation
import UIKit

/// Chat view implementation, extends UINavigationController with a ChatViewController put as a root view controller.
open class MMChatNavigationVC: UINavigationController {
    var customTransitioningDelegate: UIViewControllerTransitioningDelegate?
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
    
    static func makeChatNavigationViewController(transitioningDelegate: UIViewControllerTransitioningDelegate? = nil) -> MMChatNavigationVC {
        if let transitioningDelegate = transitioningDelegate {
            let nc = MMChatNavigationVC.init(rootViewController : MMChatViewController(type: .custom, image: UIImage(mm_chat_named: "backButton")))
            nc.customTransitioningDelegate = transitioningDelegate
            nc.transitioningDelegate = transitioningDelegate
            nc.modalPresentationStyle = .custom
            return nc
        } else {
            let nc = MMChatNavigationVC.init(rootViewController : MMChatViewController(type: .dismiss))
            return nc
        }
    }
}
