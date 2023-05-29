//
//  ComposeBar_Button.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 08/12/2017.
//

import Foundation
import UIKit

class ComposeBar_Button: UIButton {
    var enabledTintColor: UIColor! = UIColor.black {
        didSet {
            if (isEnabled) {
                tintColor = enabledTintColor
            }
        }
    }
	var disabledTintColor: UIColor! = UIColor.gray
	override var isHighlighted: Bool {
		didSet {
			if (isHighlighted) {
				alpha = 0.2
			} else {
				UIView.animate(withDuration: 0.2, delay: 0, options: .beginFromCurrentState, animations: { self.alpha = 1.0 }, completion: nil)
			}
		}
	}
	override var isEnabled: Bool {
		didSet {
			if (isEnabled) {
				tintColor = enabledTintColor
			} else {
				tintColor = disabledTintColor
			}
		}
	}
}

class ComposeBar_Send_Button: ComposeBar_Button {
	init() {
		super.init(frame: CGRect.zero)
		titleEdgeInsets = UIEdgeInsets(top: 0.5, left: 0, bottom: 0, right: 0)
		tintColor = enabledTintColor
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
