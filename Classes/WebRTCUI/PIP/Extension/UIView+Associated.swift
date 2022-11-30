//
//  UIView+Associated.swift
//  PIPKit
//
//  Created by Kofktu on 2022/01/03.
//

import Foundation
import UIKit

extension UIView {
    
    enum MMAssociatedKeys {
        static var avUIKitRenderer = "avUIKitRenderer"
        static var pipVideoController = "PIPVideoController"
    }
    
    @available(iOS 15.0, *)
    internal var avUIKitRenderer: AVPIPUIKitRenderer? {
        get { return objc_getAssociatedObject(self, &MMAssociatedKeys.avUIKitRenderer) as? AVPIPUIKitRenderer }
        set { objc_setAssociatedObject(self, &MMAssociatedKeys.avUIKitRenderer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    @available(iOS 15.0, *)
    internal var videoController: AVPIPKitVideoController? {
        get { objc_getAssociatedObject(self, &MMAssociatedKeys.pipVideoController) as? AVPIPKitVideoController }
        set { objc_setAssociatedObject(self, &MMAssociatedKeys.pipVideoController, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
}
