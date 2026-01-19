// 
//  UIWindow+Extension.swift
//  MobileMessaging
//
//  Copyright (c) 2016-2026 Infobip Limited
//  Licensed under the Apache License, Version 2.0
//

import UIKit

extension UIApplication {
    
    public var mmkeyWindow: UIWindow? {
        var sceneWindows: [UIWindow]?
        sceneWindows = connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first { $0 is UIWindowScene }
            .flatMap { $0 as? UIWindowScene }?.windows

        let windows = sceneWindows
        return windows?.first(where: \.isKeyWindow) ?? windows?.first
    }
    
    public static var mmCenter: CGPoint {
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        return CGPoint(x: screenWidth / 2, y: screenHeight / 2)
    }
    
}
