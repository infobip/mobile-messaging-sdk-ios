//
//  CPViewController.swift
//
//  Created by Andrey Kadochnikov on 15.07.15.
//

import UIKit

enum CPBackButtonType {
	case back
	case dismiss
}

open class CPModalDismissableViewController: UIViewController {
	var isModal: Bool = false

	public override func viewWillAppear(_ animated: Bool) {
		if isBeingPresented {
			isModal = true
		} else if isMovingToParent {
			isModal = false
		}
	}
	
	public required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)!
	}

	init(type: CPBackButtonType) {
		super.init(nibName: nil, bundle: nil)
		self.setupType(type)
	}

	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
	}
	
	func setupType(_ type: CPBackButtonType) {
		switch type {
		case .back:
			self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItem.Style.plain, target: self, action: nil)
			self.navigationItem.backBarButtonItem?.title = ""
		case .dismiss:
			let dismissBarBtn = UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(CPModalDismissableViewController.closeVC))
			self.navigationItem.rightBarButtonItem = dismissBarBtn;
		}
	}
	
	public override func viewDidLoad() {
		super.viewDidLoad()
		self.edgesForExtendedLayout = UIRectEdge()
		if #available(iOS 13, *) {
			self.view.backgroundColor = UIColor.systemBackground
		} else {
			self.view.backgroundColor = UIColor.white
		}
		self.navigationItem.backBarButtonItem = UIBarButtonItem(title:"", style:UIBarButtonItem.Style.plain, target:nil, action:nil)
		self.navigationItem.backBarButtonItem?.title = ""
	}
	
	@objc func closeVC() {
		self.dismiss(animated: true, completion: nil)
	}
}
