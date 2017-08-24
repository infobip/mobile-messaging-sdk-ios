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
		UIToolbar.appearance().barTintColor = customBarColor
		UIToolbar.appearance().tintColor = customTintColor
	}
}
