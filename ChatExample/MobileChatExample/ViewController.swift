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

class ViewController: UIViewController, InAppChatDelegate {
	@IBOutlet weak var showChatInNavigation: UIButton!
	@IBOutlet weak var showChatModally: UIButton!
	@IBOutlet weak var showChatInNavigationProgrammatically: UIButton!
	@IBOutlet weak var showChatModallyProgrammatically: UIButton!
	@IBOutlet weak var presentRootNavigationVC: UIButton!

	override func viewDidLoad() {
		super.viewDidLoad()
		MobileMessaging.inAppChat?.delegate = self
	}
	
	@IBAction func showChatInNavigationP(_ sender: Any) {
		let vc = CPChatViewController.makeChildNavigationViewController()
		navigationController?.pushViewController(vc, animated: true)
	}
	@IBAction func showChatModallyP(_ sender: Any) {
		let vc = CPChatViewController.makeModalViewController()
		navigationController?.present(vc, animated: true, completion: nil)
	}
	@IBAction func presentRootNavigationVC(_ sender: Any) {
		let vc = CPChatViewController.makeRootNavigationViewController()
		vc.modalPresentationStyle = .fullScreen
		navigationController?.present(vc, animated: true, completion: nil)
	}

	func inAppChatIsEnabled(_ enabled: Bool) {
		enableButtons(enabled: enabled)
	}
	
	func enableButtons(enabled: Bool) {
		showChatInNavigation.isEnabled = enabled
		showChatModally.isEnabled = enabled
		showChatInNavigationProgrammatically.isEnabled = enabled
		showChatModallyProgrammatically.isEnabled = enabled
		presentRootNavigationVC.isEnabled = enabled
	}
}
