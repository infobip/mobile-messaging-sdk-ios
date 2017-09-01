//
//  ViewControllerWithToolbar.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 01.09.17.
//

import UIKit

class ViewControllerWithToolbar: UIViewController {
	static let toolbarHeight: CGFloat = 64
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// init toolbar
		let toolbarView = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: ViewControllerWithToolbar.toolbarHeight))
		toolbarView.autoresizingMask = [.flexibleWidth]
		toolbarView.setItems([UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close)),
		                      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
		                      UIBarButtonItem(title: self.title, style: .plain, target: nil, action: nil),
		                      UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)],
		                     animated: true)
		
		view.addSubview(toolbarView)
	}
	
	func close() {
		dismiss(animated: true)
	}
}

