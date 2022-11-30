//
//  AVPIPKitUsable.swift
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
import AVKit

public extension PIPKit {
 
    static var isAVPIPKitSupported: Bool {
        guard #available(iOS 15.0, *) else {
            return false
        }
        
        return AVPictureInPictureController.isPictureInPictureSupported()
    }
     
}

@available(iOS 15.0, *)
public enum AVPIPKitRenderPolicy {
    
    case once
    case preferredFramesPerSecond(Int)
    
}

@available(iOS 15.0, *)
extension AVPIPKitRenderPolicy {
    
    var preferredFramesPerSecond: Int {
        switch self {
        case .once:
            return 1
        case .preferredFramesPerSecond(let preferredFramesPerSecond):
            return preferredFramesPerSecond
        }
    }
    
}

@available(iOS 15.0, *)
public protocol AVPIPKitUsable {
    
    var renderer: AVPIPKitRenderer { get }
    
    func startPictureInPicture()
    func stopPictureInPicture()
    
}

@available(iOS 15.0, *)
public extension AVPIPKitUsable {
    
    var isAVKitPIPSupported: Bool {
        PIPKit.isAVPIPKitSupported
    }
    
}

