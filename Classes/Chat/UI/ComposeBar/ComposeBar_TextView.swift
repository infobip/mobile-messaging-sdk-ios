//
//  ComposeBar_TextView.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 08/12/2017.
//

import Foundation

class ComposeBar_TextView: UITextView {
	override var contentOffset: CGPoint {
		set {
			if selectedRange.length != 0 || isTracking || isDecelerating {
				super.contentOffset = newValue
			}
		}
		get {
			return super.contentOffset
		}
	}
	
	var primitiveContentOffset: CGPoint {
		set {
			super.contentOffset = newValue
		}
		get {
			return super.contentOffset
		}
	}
}
