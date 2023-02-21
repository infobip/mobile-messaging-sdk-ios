//
//  AVPIPKitUsable+UIKit.swift
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
import Combine

@available(iOS 15.0, *)
public protocol AVPIPUIKitUsable: AVPIPKitUsable {
    
    var pipTargetView: UIView { get }
    var renderPolicy: AVPIPKitRenderPolicy { get }
    var exitPublisher: AnyPublisher<Void, Never> { get }
    
}

@available(iOS 15.0, *)
public extension AVPIPUIKitUsable {
    
    var renderPolicy: AVPIPKitRenderPolicy {
        .preferredFramesPerSecond(UIScreen.main.maximumFramesPerSecond)
    }
    
}

@available(iOS 15.0, *)
public extension AVPIPUIKitUsable where Self: UIViewController {
    
    var pipTargetView: UIView { view }
    var renderer: AVPIPKitRenderer {
        setupRendererIfNeeded()
        return avUIKitRenderer.unsafelyUnwrapped
    }
    var exitPublisher: AnyPublisher<Void, Never> {
        setupRendererIfNeeded()
        return avUIKitRenderer.unsafelyUnwrapped.exitPublisher
    }
    
    func startPictureInPicture() {
        setupIfNeeded()
        videoController?.start()
    }
    
    func stopPictureInPicture() {
        assert(videoController != nil)
        videoController?.stop()
    }
    
    // If you want to update the screen, execute the following additional code.
    func renderPictureInPicture() {
        setupRendererIfNeeded()
        avUIKitRenderer?.render()
    }
    
    // MARK: - Private
    private func setupRendererIfNeeded() {
        guard avUIKitRenderer == nil else {
            return
        }
        
        avUIKitRenderer = AVPIPUIKitRenderer(targetView: pipTargetView, policy: renderPolicy)
    }
    
    private func setupIfNeeded() {
        guard videoController == nil else {
            return
        }
        
        videoController = createVideoController()
    }
    
}

@available(iOS 15.0, *)
public extension AVPIPUIKitUsable where Self: UIView {
    
    var pipTargetView: UIView { self }
    var renderer: AVPIPKitRenderer {
        setupRendererIfNeeded()
        return avUIKitRenderer.unsafelyUnwrapped
    }
    var exitPublisher: AnyPublisher<Void, Never> {
        setupRendererIfNeeded()
        return avUIKitRenderer.unsafelyUnwrapped.exitPublisher
    }
    
    func startPictureInPicture() {
        setupIfNeeded()
        videoController?.start()
    }
    
    func stopPictureInPicture() {
        assert(videoController != nil)
        videoController?.stop()
    }
    
    // If you want to update the screen, execute the following additional code.
    func renderPictureInPicture() {
        setupRendererIfNeeded()
        avUIKitRenderer?.render()
    }
    
    // MARK: - Private
    private func setupRendererIfNeeded() {
        guard avUIKitRenderer == nil else {
            return
        }
        
        avUIKitRenderer = AVPIPUIKitRenderer(targetView: pipTargetView, policy: renderPolicy)
    }
    
    private func setupIfNeeded() {
        guard videoController == nil else {
            return
        }
        
        videoController = createVideoController()
    }
    
}
