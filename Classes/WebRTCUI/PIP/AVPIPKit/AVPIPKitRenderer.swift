//
//  AVPIPKitRenderer.swift
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
import Combine
import UIKit

@available(iOS 15.0, *)
public protocol AVPIPKitRenderer {
    
    var policy: AVPIPKitRenderPolicy { get }
    var renderPublisher: AnyPublisher<UIImage, Never> { get }
    
    func start()
    func stop()
    func exit()
    
}

@available(iOS 15.0, *)
final class AVPIPUIKitRenderer: AVPIPKitRenderer {
    
    let policy: AVPIPKitRenderPolicy
    var renderPublisher: AnyPublisher<UIImage, Never> {
        _render
            .filter { $0 != nil }
            .map { $0.unsafelyUnwrapped }
            .eraseToAnyPublisher()
    }
    var exitPublisher: AnyPublisher<Void, Never> {
        _exit.eraseToAnyPublisher()
    }
    
    private var isRunning: Bool = false
    private weak var targetView: UIView?
    private var displayLink: CADisplayLink?
    private let _render = CurrentValueSubject<UIImage?, Never>(nil)
    private let _exit = PassthroughSubject<Void, Never>()
    
    deinit {
        stop()
    }
    
    init(targetView: UIView, policy: AVPIPKitRenderPolicy) {
        self.targetView = targetView
        self.policy = policy
    }
    
    func start() {
        if isRunning {
            return
        }
        
        isRunning = true
        onRender()
        
        guard case .preferredFramesPerSecond(let preferredFramesPerSecond) = policy else {
            return
        }
        
        displayLink = CADisplayLink(target: self, selector: #selector(onRender))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 1, maximum: Float(preferredFramesPerSecond), preferred: 0)
        displayLink?.add(to: .main, forMode: .default)
    }
    
    func stop() {
        guard isRunning else {
            return
        }
        
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false
    }
    
    func exit() {
        _exit.send(())
    }
    
    func render() {
        onRender()
    }
    
    // MARK: - Private
    @objc private func onRender() {
        guard let targetView = targetView else {
            stop()
            return
        }
        
        _render.send(targetView.uiImage)
    }
    
}

@available(iOS 15.0, *)
private extension UIView {
    
    var uiImage: UIImage {
        UIGraphicsImageRenderer(bounds: bounds).image { context in
            layer.render(in: context.cgContext)
        }
    }
    
}
