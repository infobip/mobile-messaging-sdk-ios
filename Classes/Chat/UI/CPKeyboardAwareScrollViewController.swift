//
//  CPKeyboardAwareScrollViewController.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 14.04.2020.
//

import Foundation
import UIKit

open class MMKeyboardAwareScrollViewController : MMKeyboardAwareViewController {
    var scrollView: UIScrollView! {
        return nil
    }

    var scrollViewContainer: UIView! {
        return nil
    }
    
    // MARK: - Keyboard
    override func keyboardWillHide(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
        guard MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance else { return }
        super.keyboardWillHide(duration, curve: curve, options: options, height: height)
        updateScrollViewContainerHeightAnimated(duration, options, height)
    }

    override func keyboardWillShow(_ duration: TimeInterval, curve: UIView.AnimationCurve, options: UIView.AnimationOptions, height: CGFloat) {
        guard MMChatSettings.sharedInstance.shouldHandleKeyboardAppearance else { return }
        super.keyboardWillShow(duration, curve: curve, options: options, height: height)
        updateScrollViewContainerHeightAnimated(duration, options, height)
    }
    
    private func updateScrollViewContainerHeightAnimated(_ duration: TimeInterval, _ options: UIView.AnimationOptions, _ bottomOffset: CGFloat) {
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            self.scrollViewContainer.frame.height = self.view.bounds.height - bottomOffset - self.safeAreaInsets.top
        }, completion: nil)
    }
    
    var safeAreaInsets: UIEdgeInsets = UIEdgeInsets.zero
    
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if safeAreaInsets != view.safeAreaInsets {
            safeAreaInsets = view.safeAreaInsets
            updateViewsFor(safeAreaInsets: safeAreaInsets, safeAreaLayoutGuide: view.safeAreaLayoutGuide)
        }
    }
    
    func updateViewsFor(safeAreaInsets: UIEdgeInsets, safeAreaLayoutGuide: UILayoutGuide) {}
}
