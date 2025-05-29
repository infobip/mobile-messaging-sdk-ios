//
//  UIViewController+Associated.swift
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

extension UIViewController {
    
    enum MMAssociatedKeys {
        static var pipEventDispatcher = "pipEventDispatcher"
        static var avUIKitRenderer = "avUIKitRenderer"
        static var pipVideoController = "PIPVideoController"
    }
    
    internal  var pipEventDispatcher: PIPKitEventDispatcher? {
        get {
            return withUnsafePointer(to: &MMAssociatedKeys.pipEventDispatcher) {
                  return objc_getAssociatedObject(self, $0) as? PIPKitEventDispatcher
                }
        }
        set {
            withUnsafePointer(to: &MMAssociatedKeys.pipEventDispatcher) {
                objc_setAssociatedObject(self, $0, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    @available(iOS 15.0, *)
    internal  var avUIKitRenderer: AVPIPUIKitRenderer? {
        get {
            return withUnsafePointer(to: &MMAssociatedKeys.avUIKitRenderer) {
                  return objc_getAssociatedObject(self, $0) as? AVPIPUIKitRenderer
                }
        }
        set {
            withUnsafePointer(to: &MMAssociatedKeys.avUIKitRenderer) {
                objc_setAssociatedObject(self, $0, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    @available(iOS 15.0, *)
    internal  var videoController: AVPIPKitVideoController? {
        get {
            return withUnsafePointer(to: &MMAssociatedKeys.pipVideoController) {
                  return objc_getAssociatedObject(self, $0) as? AVPIPKitVideoController
                }
        }
        set {
            withUnsafePointer(to: &MMAssociatedKeys.pipVideoController) {
                objc_setAssociatedObject(self, $0, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
}

