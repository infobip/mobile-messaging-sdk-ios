// 
//  ComposeBar_TextView.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
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
