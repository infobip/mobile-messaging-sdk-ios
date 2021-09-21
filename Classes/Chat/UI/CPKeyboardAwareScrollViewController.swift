//
//  CPKeyboardAwareScrollViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14.04.2020.
//

import Foundation

open class MMKeyboardAwareScrollViewController : MMKeyboardAwareViewController {
    var scrollView: UIScrollView! {
        return nil
    }

    var scrollViewContainer: UIView! {
        return nil
    }

    // MARK: - Keyboard
    override func keyboardWillHide(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
        let block = {
            self.scrollViewContainer.frame.height = self.view.bounds.height - self.safeAreaInsets.bottom - height
        }
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: block, completion: nil)
        super.keyboardWillHide(duration, curve: curve, options: options, height: height)
    }

    override func keyboardWillShow(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
        let block = {
            self.scrollViewContainer.frame.height = self.view.bounds.height - height - self.safeAreaInsets.bottom
        }
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: block, completion: nil)
        super.keyboardWillShow(duration, curve: curve, options: options, height: height)
    }
    
    var safeAreaInsets: UIEdgeInsets = UIEdgeInsets.zero
    
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if #available(iOS 11.0, *) {
            if safeAreaInsets != view.safeAreaInsets {
                safeAreaInsets = view.safeAreaInsets
                updateViewsFor(safeAreaInsets: safeAreaInsets, safeAreaLayoutGuide: view.safeAreaLayoutGuide)
            }
        }
    }
    
    func updateViewsFor(safeAreaInsets: UIEdgeInsets, safeAreaLayoutGuide: UILayoutGuide) {}
}
