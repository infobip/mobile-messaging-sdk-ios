//
//  ChatUtils.swift
//  MobileMessaging
//
//  Created by okoroleva on 30.11.17.
//


extension NSAttributedString {
    #if swift(>=4.0)
	static let foregroundColorAttributeName =  NSAttributedString.Key.foregroundColor
	static let fontAttributeName =  NSAttributedString.Key.font
	static let paragraphStyleAttributeName =  NSAttributedString.Key.paragraphStyle
    #else
    static let foregroundColorAttributeName = NSForegroundColorAttributeName
    static let fontAttributeName = NSFontAttributeName
    static let paragraphStyleAttributeName =  NSParagraphStyleAttributeName
    #endif
}
