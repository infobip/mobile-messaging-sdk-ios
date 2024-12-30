//
//  UIToolbarExtension.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 24.08.17.
//

import UIKit

let customBarColor = UIColor(red: 0xF0 / 255.0, green: 0x7D / 255.0, blue: 0x15 / 255.0, alpha: 1.0)
let customTintColor = UIColor.white

extension UIToolbar {
    class func setupAppearance() {
        if #available(iOS 13.0, *) {
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.backgroundColor = customBarColor
            navBarAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: customTintColor]
            navBarAppearance.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor: customTintColor]
            
            UINavigationBar.appearance().standardAppearance = navBarAppearance
            UINavigationBar.appearance().compactAppearance = navBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
            
            // Add toolbar appearance for iOS 13+
            let toolbarAppearance = UIToolbarAppearance()
            toolbarAppearance.backgroundColor = customBarColor
            toolbarAppearance.configureWithDefaultBackground()
            
            UIToolbar.appearance().standardAppearance = toolbarAppearance
            
            if #available(iOS 15.0, *) {
                UIToolbar.appearance().scrollEdgeAppearance = toolbarAppearance
            }
        } else {
            UIToolbar.appearance().barTintColor = customBarColor
            UIToolbar.appearance().tintColor = customTintColor
        }
    }
}
