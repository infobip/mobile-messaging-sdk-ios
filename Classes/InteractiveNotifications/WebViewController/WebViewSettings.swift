//
//  WebViewSettings.swift
//  MobileMessaging
//
//  Created by Olga Koroleva on 11.11.2020.
//

import Foundation


public class WebViewSettings: NSObject {
    
    public static let sharedInstance = WebViewSettings()
    
    public var title: String? //Custom title
    public var barTintColor: UIColor? //Toolbar color
    public var titleColor: UIColor? //Toolbar title color
    public var tintColor: UIColor? //Toolbar button color
    public var activityIndicator: ActivityIndicatorProtocol? //Implement your own UIView subclass that conforms to ActivityIndicatorProtocol protocol to replace the standard activity indicator
}

//For plugins
extension WebViewSettings {
    struct Keys {
        static let title = "title"
        static let barTintColor = "barTintColor"
        static let titleColor = "titleColor"
        static let tintColor = "tintColor"
    }

    public func configureWith(rawConfig: [String: AnyObject]) {
        if let title = rawConfig[WebViewSettings.Keys.title] as? String {
            self.title = title
        }
        if let barTintColor = rawConfig[WebViewSettings.Keys.barTintColor] as? String {
            self.barTintColor = UIColor(hexString: barTintColor)
        }
        if let titleColor = rawConfig[WebViewSettings.Keys.titleColor] as? String {
            self.titleColor = UIColor(hexString: titleColor)
        }
        if let tintColor = rawConfig[WebViewSettings.Keys.tintColor] as? String {
            self.tintColor = UIColor(hexString: tintColor)
        }
    }
}
