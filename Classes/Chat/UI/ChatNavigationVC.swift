//
//  CPChatNavigationVC.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 07/11/2017.
//

import Foundation

/// Chat view implementation, extends UINavigationController with a ChatViewController put as a root view controller.
open class ChatNavigationVC: UINavigationController {
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
    
    static func makeChatNavigationViewController(transitioningDelegate: UIViewControllerTransitioningDelegate? = nil) -> ChatNavigationVC {
        if let transitioningDelegate = transitioningDelegate {
            let nc = ChatNavigationVC.init(rootViewController : ChatViewController(type: .custom, image: UIImage(mm_named: "backButton")))
            nc.customTransitioningDelegate = transitioningDelegate
            nc.transitioningDelegate = transitioningDelegate
            nc.modalPresentationStyle = .custom
            return nc
        } else {
            let nc = ChatNavigationVC.init(rootViewController : ChatViewController(type: .dismiss))
            return nc
        }
    }
}
