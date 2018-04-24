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

open class CPViewController: UIViewController {
	var keyboardShown: Bool = false
	var isModal: Bool = false
	open override func viewWillAppear(_ animated: Bool) {
		if isBeingPresented {
			isModal = true
		} else if isMovingToParentViewController {
			isModal = false
		}
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self)
	}
	
	public required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)!
	}
	
	init() {
		super.init(nibName: nil, bundle: nil)
		self.setupType(.back)
	}
	
//	init(type: CPBackButtonType) {
//		super.init(nibName: nil, bundle: nil)
//		self.setupType(type)
//	}
	
//	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
//		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
//	}
	
//	required init(coder aDecoder: NSCoder) {
//		super.init(coder: aDecoder)
//	}
	
//	init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?, type: CPBackButtonType) {
//		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
//		self.setupType(type)
//	}

	func setupType(_ type: CPBackButtonType) {
		switch type {
		case .back:
			self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: UIBarButtonItemStyle.plain, target: self, action: nil)
		case .dismiss:
			let dismissBarBtn = UIBarButtonItem(image: UIImage(named: "navbar_black_cross"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(CPViewController.closeVC))
			self.navigationItem.leftBarButtonItem = dismissBarBtn;
		}
	}
	
	override open func viewDidLoad() {
		super.viewDidLoad()
		self.edgesForExtendedLayout = UIRectEdge()
		self.view.backgroundColor = UIColor.white
		self.navigationItem.backBarButtonItem = UIBarButtonItem(title:"", style:UIBarButtonItemStyle.plain, target:nil, action:nil)
		NotificationCenter.default.addObserver(self, selector: #selector(CPViewController.keyboardDidShow(_:)), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(CPViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(CPViewController.keyboardDidHide(_:)), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(CPViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
	}
	
    @objc func closeVC() {
		self.dismiss(animated: true, completion: nil)
	}
	
	func showActionSheet(_ title: String, actions: [UIAlertAction]) {
		let sheet = UIAlertController(title: title, message: "", preferredStyle: UIAlertControllerStyle.actionSheet)
		for a in actions {
			sheet.addAction(a)
		}
		self.present(sheet, animated: true, completion: nil)
	}
	
    @objc final func keyboardWillShow(_ n: Notification) {
		keyboardShown = true
		if let userInfo = (n as NSNotification).userInfo,
			let animationDuration = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
			let animationCurve = (userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue,
			let keyboardHeight = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height
		{
			let viewFrameInWindow = view.convert(view.bounds, to: nil)
			let bottomGap = UIScreen.main.bounds.height - viewFrameInWindow.maxY

			
			let options = UIViewAnimationOptions(rawValue: UInt(animationCurve << 16))
			self.keyboardWillShow(animationDuration, curve: UIViewAnimationCurve(rawValue: Int(animationCurve)) ?? .linear, options: options, height: keyboardHeight - bottomGap)
		}
	}
	
	func keyboardWillShow(_ duration: TimeInterval, curve: UIViewAnimationCurve, options: UIViewAnimationOptions, height: CGFloat) {

	}
	
    @objc func keyboardDidShow(_ n: Notification) {
		
	}
	
    @objc final func keyboardWillHide(_ n: Notification) {
		keyboardShown = false
		if let userInfo = (n as NSNotification).userInfo,
			let animationDuration = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
			let animationCurve = (userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue,
			let keyboardHeight = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height
		{
			let options = UIViewAnimationOptions(rawValue: UInt(animationCurve << 16))
			self.keyboardWillHide(animationDuration, curve: UIViewAnimationCurve(rawValue: Int(animationCurve)) ?? .linear, options: options, height: keyboardHeight)
		}
	}
	
	func keyboardWillHide(_ duration: TimeInterval, curve: UIViewAnimationCurve, options: UIViewAnimationOptions, height: CGFloat) {
		
	}
	
    @objc func keyboardDidHide(_ n: Notification) {
		
	}
}
