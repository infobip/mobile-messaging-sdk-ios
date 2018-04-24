//
//  ChatUtils.swift
//  MobileMessaging
//
//  Created by okoroleva on 30.11.17.
//


extension NSAttributedString {
    #if swift(>=4.0)
    static let foregroundColorAttributeName =  NSAttributedStringKey.foregroundColor
    static let fontAttributeName =  NSAttributedStringKey.font
    static let paragraphStyleAttributeName =  NSAttributedStringKey.paragraphStyle
    #else
    static let foregroundColorAttributeName = NSForegroundColorAttributeName
    static let fontAttributeName = NSFontAttributeName
    static let paragraphStyleAttributeName =  NSParagraphStyleAttributeName
    #endif
}
