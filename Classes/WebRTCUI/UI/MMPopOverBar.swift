//
//  MMPopOverBar.swift
//  MobileMessaging
//
//  Created by Francisco Fortes on 06/02/2023.
//  Copyright © 2023 Infobip Ltd. All rights reserved.
//

import UIKit
#if WEBRTCUI_ENABLED
private let kGap: CGFloat = 8.0

public final class MMPopOverBar {
    public static let shared = MMPopOverBar()
    private static let kWindowLevel: UIWindow.Level = UIWindow.Level(UIWindow.Level.statusBar.rawValue + 1)
    private var popoversViews: [MMPopoverView] = [] {
        didSet {
            if let popoverView = popoversViews.first, popoverView.state == .queued {
                show(popoverView)
            }
        }
    }
    private var options = Options(shouldConsiderSafeArea: true, isStretchable: true, textAlignment: .left)
    private var baseView = UIView(frame: UIScreen.main.bounds)
    private var safeArea: UIEdgeInsets {
        let window = UIApplication.shared.keyWindow
        return window?.safeAreaInsets ?? .zero
    }

    public struct Options {
        let shouldConsiderSafeArea: Bool
        let isStretchable: Bool
        let textAlignment: NSTextAlignment
        let font: UIFont

        public init(
            shouldConsiderSafeArea: Bool = true,
            isStretchable: Bool = false,
            textAlignment: NSTextAlignment = .natural,
            font: UIFont = UIFont.systemFont(ofSize: 14.0)) {
            self.shouldConsiderSafeArea = shouldConsiderSafeArea
            self.isStretchable = isStretchable
            self.textAlignment = textAlignment
            self.font = font
        }
    }

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.deviceRotated),
                                               name: UIDevice.orientationDidChangeNotification, object: nil)
    }

    public func setDefault(options: Options) {
        self.options = options
    }

    public func show(backgroundColor: UIColor,
                     textColor: UIColor,
                     message: String,
                     duration: TimeInterval = 3,
                     style: MMPopupView.BrandStyle = .error,
                     options: Options? = nil,
                     completion: (() -> Void)? = nil,
                     presenterVC: UIViewController) {
        DispatchQueue.main.async {
            let currentOptions = options ?? self.options
            self.baseView.frame = UIScreen.main.bounds
            presenterVC.view.addSubview(self.baseView)
            let popoverView = MMPopoverView(frame: .zero, style: style)
            popoverView.backgroundColor = backgroundColor
            popoverView.messageLabel.textColor = textColor
            popoverView.messageLabel.text = message
            popoverView.messageLabel.numberOfLines = currentOptions.isStretchable ? 0 : 1
            popoverView.messageLabel.textAlignment = currentOptions.textAlignment
            popoverView.messageLabel.font = currentOptions.font
            popoverView.shouldConsiderSafeArea = currentOptions.shouldConsiderSafeArea
            popoverView.duration = duration
            self.popoversViews.append(popoverView)
        }
    }

    private func show(_ popoverView: MMPopoverView) {
        let statusBarHeight: CGFloat = max(48.0, safeArea.top)
        let alertBarHeight: CGFloat = max(statusBarHeight, popoverView.frame.height)
        self.baseView.addSubview(popoverView)
        popoverView.frame.size.width = self.getFrameBasedOnOrientation().width
        popoverView.fit(safeArea: popoverView.shouldConsiderSafeArea ? self.safeArea : .zero)
        baseView.frame = popoverView.frame
        popoverView.show(duration: popoverView.duration, translationY: -alertBarHeight) {
            if let index = self.popoversViews.firstIndex(of: popoverView) {
                self.popoversViews.remove(at: index)
                if self.popoversViews.isEmpty {
                    self.baseView.removeFromSuperview()
                }
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func getFrameBasedOnOrientation() -> CGRect {
        let isLandscape = UIApplication.shared.statusBarOrientation.isLandscape
        return CGRect(x: kGap, y: isLandscape ? kGap : max(48.0, safeArea.top),
                      width: UIScreen.main.bounds.width, height: 0)
    }

    @objc public func deviceRotated() {
        DispatchQueue.main.async {
            self.baseView.frame = self.getFrameBasedOnOrientation()
            if let popoverView = self.popoversViews.first, popoverView.state == .showing {
                popoverView.frame.size.width = self.baseView.frame.size.width
                popoverView.fit(safeArea: popoverView.shouldConsiderSafeArea ? self.safeArea : .zero)
            }
        }
    }
}

// MARK: - Static helpers

public extension MMPopOverBar {
    static func setDefault(options: Options) {
        shared.options = options
    }

    static func show(backgroundColor: UIColor, textColor: UIColor, message: String, duration: TimeInterval = 3,
                     options: Options? = nil, completion: (() -> Void)? = nil, presenterVC: UIViewController) {
        shared.show(backgroundColor: backgroundColor,
                    textColor: textColor, message: message, duration: duration,
                    options: options, completion: completion, presenterVC: presenterVC)
    }

    static func hide() {
        DispatchQueue.main.async {
            shared.popoversViews.forEach({ $0.hide() })
        }
    }
}

internal class MMPopoverView: UIView {
    internal let messageLabel = UILabel()
    internal let iconImageV = UIImageView()

    internal enum State {
        case showing,
             hiding,
             hidden,
             queued
    }

    private static let kAnimationDuration: TimeInterval = 0.2
    private var translationY: CGFloat = 0
    private var completion: (() -> Void)?
    internal var state: State = .queued
    internal var style: MMPopupView.BrandStyle = .error
    internal var duration: TimeInterval = .zero
    internal var shouldConsiderSafeArea: Bool = true

    required public init?(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }

    public init(frame: CGRect, style: MMPopupView.BrandStyle = .error) {
        super.init(frame: frame)
        iconImageV.image = MMWebRTCSettings.sharedInstance.iconAlert
        iconImageV.frame = CGRect(x: kGap,
                                  y: kGap,
                                  width: 24,
                                  height: 24)
        messageLabel.frame = .zero
        addSubview(messageLabel)
        addSubview(iconImageV)
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(hide))
        addGestureRecognizer(gestureRecognizer)
    }

    func fit(safeArea: UIEdgeInsets) {
        messageLabel.frame.origin.x = iconImageV.frame.size.width + 2 * kGap + safeArea.left
        messageLabel.frame.origin.y = kGap + safeArea.top
        let labelWidth = frame.size.width - kGap*2 - safeArea.left - safeArea.right - iconImageV.frame.size.width
        messageLabel.frame.size.width = labelWidth
        let adjustedSize = messageLabel.sizeThatFits(CGSize(width: labelWidth, height: CGFloat.infinity))
        messageLabel.frame.size.height = adjustedSize.height
        frame.size.height = messageLabel.frame.origin.y + messageLabel.frame.height + kGap * 2
        iconImageV.center.y = messageLabel.center.y
    }

    deinit {
        print("popoverView deinit")
    }

    func show(duration: TimeInterval, translationY: CGFloat, completion: (() -> Void)?) {
        self.state = .showing
        self.translationY = translationY
        self.completion = completion

        transform = CGAffineTransform(translationX: 0, y: translationY)
        UIView.animate(
            withDuration: MMPopoverView.kAnimationDuration,
            animations: { () -> Void in
                self.transform = .identity
        }, completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int(duration))) {
                self.hide()
            }
        })
    }

    @objc func hide() {
        guard state == .showing else {
            return
        }
        self.state = .hiding
        // Hide animation
        UIView.animate(
            withDuration: MMPopoverView.kAnimationDuration,
            animations: { () -> Void in
                self.transform = CGAffineTransform(translationX: 0, y: self.translationY)
        },
            completion: { _ -> Void in
                self.removeFromSuperview()
                self.state = .hidden
                self.completion?()
                self.completion = nil
        })
    }
}
#endif
