// 
//  Example/MobileMessagingExample/ViewControllers/DeeplinkViewControllers.swift
//  MobileMessagingExample
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import UIKit
import MobileMessaging

protocol DeeplinkLandingViewController {
	static var deeplinkIdentifier: String { get }
	func handle(message: MM_MTMessage)
}

class RedViewController: ViewControllerWithToolbar, DeeplinkLandingViewController, LabelPresentor {
	static let deeplinkIdentifier = "redScreen"
	
	func handle(message: MM_MTMessage) {
		showLabel(withText: message.text)
	}
	
	override func viewDidLoad() {
		self.title = "Red screen"
		super.viewDidLoad()
		self.view.backgroundColor = UIColor.red
	}
}

class GreenViewController: ViewControllerWithToolbar, DeeplinkLandingViewController, LabelPresentor {
	static let deeplinkIdentifier = "greenScreen"
	
	func handle(message: MM_MTMessage) {
		showLabel(withText: message.text)
	}
	
	override func viewDidLoad() {
		self.title = "Green screen"
		super.viewDidLoad()
		self.view.backgroundColor = UIColor.green
	}
}

class BlueViewController: ViewControllerWithToolbar, DeeplinkLandingViewController, LabelPresentor {
	static let deeplinkIdentifier = "blueScreen"
	
	func handle(message: MM_MTMessage) {
		showLabel(withText: message.text)
	}
	
	override func viewDidLoad() {
		self.title = "Blue screen"
		super.viewDidLoad()
		self.view.backgroundColor = UIColor.blue
	}
}

protocol LabelPresentor {
	func showLabel(withText text: String?)
}

let messageLabelTag = 100

extension LabelPresentor where Self: UIViewController {
	func showLabel(withText text: String?) {
		let label = (self.view.subviews.first(where: {$0.tag == messageLabelTag}) as? UILabel) ?? UILabel(frame: self.view.frame)
		label.textAlignment = .center
		label.numberOfLines = 0
		label.text = text
		view.addSubview(label)
	}
}
