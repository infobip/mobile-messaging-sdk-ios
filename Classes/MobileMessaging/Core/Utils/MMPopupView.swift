// 
//  MMPopupView.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2025 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import UIKit

@objc
public class MMPopupView: UIAlertController {
    public static func display(
        title: String?, 
        message: String?,
        foregroundColor: UIColor,
        backgroundColor: UIColor,
        actions: [UIAlertAction] = [UIAlertAction(title: MMLoc.ok, style: .cancel, handler: nil)],
        in viewController: UIViewController) {
        DispatchQueue.mmEnsureMain {
            let popup = MMPopupView(title: title, message: message,
                                    preferredStyle: .alert)
            if UIDevice.current.userInterfaceIdiom == .pad,
                let popoverController = popup.popoverPresentationController {
                popoverController.sourceView = viewController.view
                popoverController.sourceRect = viewController.view.frame
                popoverController.permittedArrowDirections = []
            }
            popup.mmSetup(backgroundColor: backgroundColor,
                          titleColor: foregroundColor,
                          messageColor: foregroundColor,
                          buttonsLabelColor: foregroundColor,
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
