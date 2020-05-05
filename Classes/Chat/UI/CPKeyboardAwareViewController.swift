//
//  CPKeyboardAwareViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14.04.2020.
//

import Foundation

open class CPKeyboardAwareViewController: CPModalDismissableViewController {
	var keyboardShown: Bool = false

	deinit { NotificationCenter.default.removeObserver(self) }

	override open func viewDidLoad() {
		NotificationCenter.default.addObserver(self, selector: #selector(CPKeyboardAwareViewController.keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(CPKeyboardAwareViewController.keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(CPKeyboardAwareViewController.keyboardDidHide(_:)), name: UIResponder.keyboardDidHideNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(CPKeyboardAwareViewController.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

		super.viewDidLoad()
    }

	@objc final func keyboardWillShow(_ n: Notification) {
		if let userInfo = (n as NSNotification).userInfo,
			let animationDuration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
			let animationCurve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue,
			let keyboardHeight = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height
		{
			let viewFrameInWindow = view.convert(view.bounds, to: nil)
			let bottomGap = UIScreen.main.bounds.height - viewFrameInWindow.maxY
			let options = UIView.AnimationOptions(rawValue: UInt(animationCurve << 16))
			self.keyboardWillShow(animationDuration, curve: UIView.AnimationCurve(rawValue: Int(animationCurve)) ?? .linear, options: options, height: keyboardHeight - bottomGap)
		}
	}

	func keyboardWillShow(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
		keyboardShown = true
	}

    @objc func keyboardDidShow(_ n: Notification) {
	}

    @objc final func keyboardWillHide(_ n: Notification) {
		if let userInfo = (n as NSNotification).userInfo,
			let animationDuration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
			let animationCurve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue,
			let keyboardHeight = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height
		{
			let options = UIView.AnimationOptions(rawValue: UInt(animationCurve << 16))
			self.keyboardWillHide(animationDuration, curve: UIView.AnimationCurve(rawValue: Int(animationCurve)) ?? .linear, options: options, height: keyboardHeight)
		}
	}

	func keyboardWillHide(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
		keyboardShown = false
	}

    @objc func keyboardDidHide(_ n: Notification) {
	}
}
