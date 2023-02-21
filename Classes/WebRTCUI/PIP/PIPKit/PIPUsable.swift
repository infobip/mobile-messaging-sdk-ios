//
//  PIPUsable.swift
//  PIPKit
//  MIT License
//
// Created by Taeun Kim on 07/12/2018.
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

public protocol MMPIPUsable {
    var initialState: PIPState { get }
    var initialPosition: PIPPosition { get }
    var insetsPIPFromSafeArea: Bool { get }
    var pipEdgeInsets: UIEdgeInsets { get }
    var pipSize: CGSize { get }
    var pipShadow: PIPShadow? { get }
    var pipCorner: PIPCorner? { get }
    func didChangedState(_ state: PIPState)
    func didChangePosition(_ position: PIPPosition)
}

public extension MMPIPUsable {
    var initialState: PIPState { return .pip }
    var initialPosition: PIPPosition { return .bottomRight }
    var insetsPIPFromSafeArea: Bool { return true }
    var pipEdgeInsets: UIEdgeInsets { return UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15) }
    var pipSize: CGSize { return CGSize(width: 200.0, height: (200.0 * 9.0) / 16.0) }
    var pipShadow: PIPShadow? { return PIPShadow(color: .black, opacity: 0.3, offset: CGSize(width: 0, height: 8), radius: 10) }
    var pipCorner: PIPCorner? {
        if #available(iOS 13.0, *) {
            return PIPCorner(radius: 6, curve: .continuous)
        } else {
            return PIPCorner(radius: 6, curve: nil)
        }
    }
    func didChangedState(_ state: PIPState) {}
    func didChangePosition(_ position: PIPPosition) {}
}

public extension MMPIPUsable where Self: UIViewController {
    
    func setNeedsUpdatePIPFrame() {
        guard PIPKit.isPIP else {
            return
        }
        pipEventDispatcher?.updateFrame()
    }

    func startPIPMode() {
        PIPKit.startPIPMode()
    }
    
    func stopPIPMode() {
        PIPKit.stopPIPMode()
    }
    
}

internal extension MMPIPUsable where Self: UIViewController {
    
    func pipDismiss(animated: Bool, completion: (() -> Void)?) {
        if animated {
            UIView.animate(withDuration: 0.24, delay: 0, options: .curveEaseOut, animations: { [weak self] in
                self?.view.alpha = 0.0
                self?.view.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            }) { [weak self] (_) in
                self?.view.removeFromSuperview()
                completion?()
            }
        } else {
            view.removeFromSuperview()
            completion?()
        }
    }
    
}
