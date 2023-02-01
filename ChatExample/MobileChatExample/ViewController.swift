//
//  ViewController.swift
//  MobileChatExample
//
//  Created by okoroleva on 26.04.2020.
//  Copyright © 2020 Infobip d.o.o. All rights reserved.
//

import Foundation
import UIKit
import MobileMessaging

class ViewController: UIViewController, MMInAppChatDelegate {
    @IBOutlet weak var buttonsStackView: UIStackView!

    override func viewDidLoad() {
		super.viewDidLoad()
		MobileMessaging.inAppChat?.delegate = self
	}
	
	@IBAction func showChatInNavigationP(_ sender: Any) {
		let vc = MMChatViewController.makeChildNavigationViewController()
		navigationController?.pushViewController(vc, animated: true)
	}
	
    @IBAction func showChatModallyP(_ sender: Any) {
		let vc = MMChatViewController.makeModalViewController()
		navigationController?.present(vc, animated: true, completion: nil)
	}
    
	@IBAction func presentRootNavigationVC(_ sender: Any) {
		let vc = MMChatViewController.makeRootNavigationViewController()
		navigationController?.present(vc, animated: true, completion: nil)
	}

    @IBAction func presentNavigationVCCustomTrans(_ sender: Any) {
        let vc = MMChatViewController.makeRootNavigationViewControllerWithCustomTransition()
        navigationController?.present(vc, animated: true, completion: nil)
    }
    
    @IBAction func presentAndSendContextualData(_ sender: Any) {
        // We first display the chat, and few seconds later (chat should be loaded and connected) we send
        // some contextual data. More data can be sent asynchronously while the chat is active.
        let vc = MMChatViewController.makeModalViewController()
        navigationController?.present(vc, animated: true, completion: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            vc.sendContextualData("{ demoKey: 'InAppChat Metadata Value' }") { error in
                guard let error = error else {
                    MMLogInfo("Medatata was sent")
                    return
                }
                MMLogError(("Error sending metadata: \(error.localizedDescription)"))
            }
        }
    }
    
    func inAppChatIsEnabled(_ enabled: Bool) {
		enableButtons(enabled: enabled)
	}
	
	func enableButtons(enabled: Bool) {
        buttonsStackView.isUserInteractionEnabled = enabled
        buttonsStackView.alpha = enabled ? 1.0 : 0.3
	}
}
