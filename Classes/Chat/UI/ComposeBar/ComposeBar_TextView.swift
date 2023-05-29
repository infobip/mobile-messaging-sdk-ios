//
//  ComposeBar_TextView.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 08/12/2017.
//

import Foundation
import UIKit

class ComposeBar_TextView: UITextView {
	var primitiveContentOffset: CGPoint {
		set {
            if selectedRange.length != 0 || isTracking || isDecelerating {
                super.contentOffset = newValue
            }
		}
		get {
			return super.contentOffset
		}
	}
}
