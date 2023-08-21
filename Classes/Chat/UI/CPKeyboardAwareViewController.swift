//
//  CPKeyboardAwareViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14.04.2020.
//

import Foundation
import UIKit

open class MMKeyboardAwareViewController: MMModalDismissableViewController {
	var keyboardShown: Bool = false

	deinit { NotificationCenter.default.removeObserver(self) }

	override open func viewDidLoad() {
		NotificationCenter.default.addObserver(self, selector: #selector(MMKeyboardAwareViewController.keyboardDidShow(_:)), name: UIResponder.keyboardDidShowNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(MMKeyboardAwareViewController.keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(MMKeyboardAwareViewController.keyboardDidHide(_:)), name: UIResponder.keyboardDidHideNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(MMKeyboardAwareViewController.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)

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
            keyboardShown = true
		}
	}

	func keyboardWillShow(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
		
	}

    @objc func keyboardDidShow(_ n: Notification) {
	}

    @objc final func keyboardWillHide(_ n: Notification) {
		if let userInfo = (n as NSNotification).userInfo,
			let animationDuration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue,
			let animationCurve = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue,
			let keyboardHeight = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height
		{
            guard MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance else { return }
			let options = UIView.AnimationOptions(rawValue: UInt(animationCurve << 16))
			self.keyboardWillHide(animationDuration, curve: UIView.AnimationCurve(rawValue: Int(animationCurve)) ?? .linear, options: options, height: keyboardHeight)
            keyboardShown = false
		}
	}

	func keyboardWillHide(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
		
	}

    @objc func keyboardDidHide(_ n: Notification) {
	}
}
