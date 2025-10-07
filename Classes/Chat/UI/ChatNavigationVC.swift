// 
//  ChatNavigationVC.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
    
    static func makeChatNavigationViewController(transitioningDelegate: UIViewControllerTransitioningDelegate? = nil, inputView: MMChatComposer? = nil) -> MMChatNavigationVC {
        if let transitioningDelegate = transitioningDelegate {
            let nc = makeMMChatNavigationVC(with: inputView)
            nc.customTransitioningDelegate = transitioningDelegate
            nc.transitioningDelegate = transitioningDelegate
            nc.modalPresentationStyle = .custom
            return nc
        } else {
            let nc = makeMMChatNavigationVC(with: inputView)
            return nc
        }
        
        
        func makeMMChatNavigationVC(with inputView: MMChatComposer?) -> MMChatNavigationVC {
            let chatViewController = MMChatViewController(type: .custom, image: UIImage(mm_chat_named: "backButton"))
            if let inputView = inputView {
                chatViewController.composeBarView = inputView
            }
            let nc = MMChatNavigationVC.init(rootViewController: chatViewController)
            return nc
        }
    }
}
