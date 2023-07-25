//
//  UIView+Associated.swift
//  PIPKit
//  MIT License
//
// Created by Kofktu on 2022/01/08.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
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
