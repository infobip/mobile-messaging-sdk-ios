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
	@IBOutlet weak var showChatInNavigationButton: UIButton!
	@IBOutlet weak var showChatModallyButton: UIButton!
	@IBOutlet weak var showChatInNavigationProgrammaticallyButton: UIButton!
	@IBOutlet weak var showChatModallyProgrammaticallyButton: UIButton!
	@IBOutlet weak var presentRootNavigationVCButton: UIButton!
    @IBOutlet weak var presentNavigationRootVCCustomTransButton: UIButton!
    @IBOutlet weak var showChatInTabBar: UIButton!
    @IBOutlet weak var setLanguageBtn: UIButton!
    
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
    
    func inAppChatIsEnabled(_ enabled: Bool) {
		enableButtons(enabled: enabled)
	}
	
	func enableButtons(enabled: Bool) {
		showChatInNavigationButton.isEnabled = enabled
		showChatModallyButton.isEnabled = enabled
		showChatInNavigationProgrammaticallyButton.isEnabled = enabled
		showChatModallyProgrammaticallyButton.isEnabled = enabled
		presentRootNavigationVCButton.isEnabled = enabled
        presentNavigationRootVCCustomTransButton.isEnabled = enabled
        showChatInTabBar.isEnabled = enabled
        setLanguageBtn.isEnabled = enabled
	}
}
