//
//  MMPopupView.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 04/10/2020.
//  Copyright © 2020 Infobip Ltd. All rights reserved.
//

import Foundation
import UIKit

@objc
public class MMPopupView: UIAlertController {
    
    public enum BrandStyle: Int {
        case error = 0
        case info = 1
    }
    
    public static func display(
        title: String?, 
        message: String?, 
        style: MMPopupView.BrandStyle,
        actions: [UIAlertAction] = [UIAlertAction(title: MMLoc.ok, style: .cancel, handler: nil)],
        in viewController: UIViewController) {
        DispatchQueue.main.async {
            let settings = MMWebRTCSettings.sharedInstance
            let popup = MMPopupView(title: title, message: message,
                                    preferredStyle: .alert)
            popup.mmSetup(backgroundColor: style == .error ? settings.errorColor : settings.backgroundColor,
                          titleColor: settings.foregroundColor,
                          messageColor: settings.foregroundColor,
                          buttonsLabelColor: settings.foregroundColor,
                          titleFont: UIFont(name: "Roboto", size: 20.0) ??  UIFont(name: "HelveticaNeue", size: 20.0), 
                          messageFont: UIFont(name: "Roboto", size: 14.0) ??  UIFont(name: "HelveticaNeue", size: 14.0))
            for action in actions {
                popup.addAction(action)
            }
            if let alreadyPresentedController = viewController.presentedViewController {
                if let prevPopop = alreadyPresentedController as? MMPopupView,
                   prevPopop.title == title, prevPopop.message == message {
                    return
                }
                alreadyPresentedController.present(popup, animated: true, completion: nil)
            } else {
                viewController.present(popup, animated: true, completion: nil)
            }            
        }
    }
}
