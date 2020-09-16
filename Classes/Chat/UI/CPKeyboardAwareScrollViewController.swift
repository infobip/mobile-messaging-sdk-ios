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
			self.scrollView.contentInset.top = height - self.safeAreaBottomMargin()
            self.scrollViewContainer.frame.y = -height + self.safeAreaBottomMargin()
			self.scrollView.scrollIndicatorInsets = self.scrollView.contentInset
		}
		UIView.animate(withDuration: duration, delay: 0, options: options, animations: block, completion: nil)
		super.keyboardWillShow(duration, curve: curve, options: options, height: height)
	}
    
    func safeAreaBottomMargin() -> CGFloat {
        if #available(iOS 11.0, *) {
            guard let window = UIApplication.shared.windows.first,
                let owingView = window.safeAreaLayoutGuide.owningView else {
                    return 0
            }
            return owingView.frame.height - window.safeAreaLayoutGuide.layoutFrame.height - window.safeAreaLayoutGuide.layoutFrame.origin.y;
        }
        return 0
    }
}
