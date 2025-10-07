// 
//  CPLabel.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UIKit

class MMLabel: UILabel {
	var maxLineHeight: CGFloat? = nil
	
	override var text: String? {
		didSet {
			if let text = text {
				let ats = NSMutableAttributedString(string: text)
				let paragraphStyle = NSMutableParagraphStyle()
				paragraphStyle.alignment = textAlignment
				if let maxLineHeight = maxLineHeight {
					paragraphStyle.maximumLineHeight = maxLineHeight
				}
				ats.addAttributes([
					NSAttributedString.Key.paragraphStyle: paragraphStyle,
					NSAttributedString.Key.font: font as Any,
					NSAttributedString.Key.foregroundColor: textColor as Any],
								  range: NSRange(location: 0, length: ats.length))
				attributedText = ats
			} else {
				attributedText = nil
			}
		}
	}
}
