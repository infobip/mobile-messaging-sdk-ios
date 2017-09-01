//
//  DeeplinkViewControllers.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 31.08.17.
//

import UIKit
import MobileMessaging

protocol DeeplinkLandingViewController {
	static var deeplinkIdentifier: String { get }
	func handle(message: MTMessage)
}

class RedViewController: ViewControllerWithToolbar, DeeplinkLandingViewController, LabelPresentor {
	static let deeplinkIdentifier = "redScreen"
	
	var message: MTMessage?
	
	func handle(message: MTMessage) {
		self.message = message
	}
	
	override var title: String? {
		get {return "Red screen"}
		set {}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.view.backgroundColor = UIColor.red
		showLabel(withText: message?.text)
	}
}

class GreenViewController: ViewControllerWithToolbar, DeeplinkLandingViewController, LabelPresentor {
	static let deeplinkIdentifier = "greenScreen"
	
	var message: MTMessage?
	
	func handle(message: MTMessage) {
		self.message = message
	}
	
	override var title: String? {
		get {return "Green screen"}
		set {}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.view.backgroundColor = UIColor.green
		showLabel(withText: message?.text)
	}
}

class BlueViewController: ViewControllerWithToolbar, DeeplinkLandingViewController, LabelPresentor {
	static let deeplinkIdentifier = "blueScreen"
	
	var message: MTMessage?
	
	func handle(message: MTMessage) {
		self.message = message
	}
	
	override var title: String? {
		get {return "Blue screen"}
		set {}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.view.backgroundColor = UIColor.blue
		showLabel(withText: message?.text)
	}
}

protocol LabelPresentor {
	func showLabel(withText text: String?)
}

extension LabelPresentor where Self: UIViewController {
	func showLabel(withText text: String?) {
		let label = UILabel(frame: self.view.frame)
		label.textAlignment = .center
		label.numberOfLines = 0
		label.text = text
		view.addSubview(label)
	}
}
