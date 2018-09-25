//
//  CPLabel.swift
//  MobileMessaging
//
//  Created by Andrey Kadochnikov on 01/11/2017.
//

import Foundation

class CPLabel: UILabel {
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
                ats.addAttributes([NSAttributedString.Key.paragraphStyle : paragraphStyle, NSAttributedString.Key.font : font, NSAttributedString.Key.foregroundColor : textColor], range: NSRange(location: 0, length: ats.length))
				attributedText = ats
			} else {
				attributedText = nil
			}
		}
	}
}
