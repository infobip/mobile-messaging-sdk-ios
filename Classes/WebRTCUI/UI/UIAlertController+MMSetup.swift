// 
//  UIAlertController+MMSetup.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UIKit

public extension UIAlertController {
    func mmSetup(backgroundColor: UIColor,
                 titleColor: UIColor? = nil,
                 messageColor: UIColor? = nil,
                 buttonsLabelColor: UIColor? = nil,
                 titleFont: UIFont? = nil,
                 messageFont: UIFont? = nil) {
        if let bgView = self.view.subviews.first, let groupView = bgView.subviews.first, 
           let contentView = groupView.subviews.first {
            contentView.backgroundColor = backgroundColor
        }
        
        if let title = self.title, !title.isEmpty { 
            let attributeTitleString = NSMutableAttributedString(string: title)
            if let titleFont = titleFont {
                attributeTitleString.addAttributes([NSAttributedString.Key.font: titleFont],
                                              range: NSMakeRange(0, title.count))
            }
            if let titleColor = titleColor {
                attributeTitleString.addAttributes([NSAttributedString.Key.foregroundColor: titleColor],
                                              range: NSMakeRange(0, title.count))
            }
            self.setValue(attributeTitleString, forKey: "attributedTitle") 
        }
        
        if let message = self.message, !message.isEmpty {
            let attributeMessageString = NSMutableAttributedString(string: message)
            if let messageFont = messageFont {
                attributeMessageString.addAttributes([NSAttributedString.Key.font: messageFont],
                                              range: NSMakeRange(0, message.count))
            }
            
            if let messageColor = messageColor {
                attributeMessageString.addAttributes([NSAttributedString.Key.foregroundColor: messageColor],
                                              range: NSMakeRange(0, message.count))
            }
            self.setValue(attributeMessageString, forKey: "attributedMessage")            
        }
        
        if let buttonsLabelColor = buttonsLabelColor {
            self.view.tintColor = buttonsLabelColor
        }
    }    
}
