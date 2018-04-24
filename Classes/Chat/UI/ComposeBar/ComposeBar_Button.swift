//
//  ComposeBar_Button.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 08/12/2017.
//

import Foundation

class ComposeBar_Button: UIButton {
	override var isHighlighted: Bool {
		didSet {
			if (isHighlighted) {
				alpha = 0.2
			} else {
				UIView.animate(withDuration: 0.2, delay: 0, options: .beginFromCurrentState, animations: { self.alpha = 1.0 }, completion: nil)
			}
		}
	}
}
