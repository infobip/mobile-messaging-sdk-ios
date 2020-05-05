//
//  CPKeyboardAwareScrollViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14.04.2020.
//

import Foundation

open class CPKeyboardAwareScrollViewController : CPKeyboardAwareViewController {
	var scrollView: UIScrollView! {
		return nil
	}

	var scrollViewContainer: UIView! {
		return nil
	}

	// MARK: - Keyboard
	override func keyboardWillHide(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
		let block = {
			self.scrollViewContainer.frame.y = 0
			self.scrollView.contentInset.top = 0
			self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset
		}
		UIView.animate(withDuration: duration, delay: 0, options: options, animations: block, completion: nil)
		super.keyboardWillHide(duration, curve: curve, options: options, height: height)
	}

	override func keyboardWillShow(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
		let block = {
			self.scrollView.contentInset.top = height
			self.scrollViewContainer.frame.y = -height
			self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset
		}
		UIView.animate(withDuration: duration, delay: 0, options: options, animations: block, completion: nil)
		super.keyboardWillShow(duration, curve: curve, options: options, height: height)
	}
}
